import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";
import admin from "./firebase.js";
import dayjs from "dayjs";

import { extractTextFromImages } from "./ocr.js";
import { detectLanguage } from "./detect.js"; // returns { languageCode, confidence, flutterLocale }
import { translateText } from "./translate.js"; // generic translator "src -> target"
import { generateFormattedRecipe } from "./gpt_logic.js";
import { cleanText, previewText } from "./text_utils.js";
import {
  getResolvedTier,
  enforceTranslationPolicy,
  incrementTranslationUsage,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
} from "./policy.js";

const REVENUECAT_SECRET_KEY = defineSecret("REVENUECAT_SECRET_KEY");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

// ---------------------------- helpers ----------------------------
function normalizeLangBase(code: string | undefined | null): string {
  if (!code) return "";
  return code.toLowerCase().split(/[_-]/)[0] || "";
}

function toBcp47(lang?: string, region?: string | null): string {
  const base = (lang || "en").toLowerCase();
  const reg = region ? region.toUpperCase() : "";
  return reg ? `${base}-${reg}` : base;
}

function toFlutterLocaleTag(lang?: string, region?: string | null): string {
  const base = (lang || "en").toLowerCase();
  const reg = region ? region.toUpperCase() : "";
  return reg ? `${base}_${reg}` : base;
}

// Delete a single uploaded image by its signed URL
async function deleteUploadedImage(url: string) {
  try {
    const match = url.match(/\/o\/([^?]+)\?/);
    if (!match?.[1]) {
      console.warn("❌ Could not extract path from URL:", url);
      return;
    }
    const path = decodeURIComponent(match[1]);
    const file = getStorage().bucket().file(path);
    const [exists] = await file.exists();
    if (!exists) {
      console.warn(`⚠️ Skipped deletion – file not found: ${path}`);
      return;
    }
    await file.delete();
    console.log(`🗑️ Deleted uploaded image: ${path}`);
  } catch (err) {
    console.warn(`⚠️ Error deleting image (${url}):`, err);
  }
}

// ---------------------------- main ----------------------------
export const extractAndFormatRecipe = onCall(
  {
    secrets: [REVENUECAT_SECRET_KEY, OPENAI_API_KEY],
  },
  async (request: CallableRequest<{
    imageUrls: string[];
    targetLanguage?: string; // e.g. "pl", "en"
    targetRegion?: string;   // e.g. "GB", "PL"
  }>) => {
    const start = Date.now();

    // —— Validate input
    const imageUrls = request.data?.imageUrls;
    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new HttpsError("invalid-argument", "Missing or invalid 'imageUrls' array.");
    }

    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      process.env.GCP_PROJECT ||
      "";

    if (!projectId) {
      throw new HttpsError("failed-precondition", "No project ID available.");
    }

    // —— Target locale from frontend (defaults preserved)
    const targetLanguage = (request.data?.targetLanguage || "en").toLowerCase();
    const targetRegion = (request.data?.targetRegion || "GB") || undefined;
    const targetLanguageTag = toBcp47(targetLanguage, targetRegion);              // e.g. "pl" / "en-GB"
    const targetFlutterLocale = toFlutterLocaleTag(targetLanguage, targetRegion); // e.g. "pl" / "en_GB"

    const tier = await getResolvedTier(uid);
    console.log(`🎟️ Subscription tier resolved as: ${tier}`);
    console.log(`🎯 Target: ${targetLanguageTag} (flutter: ${targetFlutterLocale})`);

    // We always try to clean up uploaded images even if processing fails
    try {
      console.log(`📸 Starting processing of ${imageUrls.length} image(s)...`);

      // —— OCR
      const ocrText = await extractTextFromImages(imageUrls);
      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }

      const cleanInput = cleanText(ocrText);
      previewText("🔎 Raw OCR text", ocrText);

      // —— Language detection
      let detectedLanguage = "unknown";
      let confidence = 0;
      let flutterLocale = "en_GB";

      try {
        const detection = await detectLanguage(cleanInput, projectId);
        detectedLanguage = detection.languageCode || "unknown";
        confidence = detection.confidence ?? 0;
        flutterLocale = detection.flutterLocale || "en_GB";
        console.log(
          `🌐 Detected language: ${detectedLanguage} (conf: ${confidence}) → flutterLocale: ${flutterLocale}`
        );
      } catch (err) {
        console.warn("⚠️ Language detection failed:", err);
      }

      // —— Decide if translation is needed
      const srcBase = normalizeLangBase(detectedLanguage);
      const tgtBase = normalizeLangBase(targetLanguage);
      const alreadyTarget = srcBase && tgtBase && srcBase === tgtBase;

      let usedText = cleanInput;
      let translationUsed = false;

      if (!srcBase) {
        console.log("🤷 Detection returned unknown — skipping translation.");
      } else if (!alreadyTarget) {
        try {
          console.log(`🚧 Translating from "${detectedLanguage}" → ${targetLanguageTag}...`);
          const translated = await translateText(
            cleanInput,
            detectedLanguage,
            targetLanguageTag,
            projectId
          );
          const cleanedTranslated = cleanText(translated || "");
          if (cleanedTranslated) {
            usedText = cleanedTranslated;
            translationUsed = true;
            previewText("📝 Translated preview", usedText);

            if (cleanText(cleanInput) !== cleanedTranslated) {
              await enforceTranslationPolicy(uid);
              await incrementTranslationUsage(uid);
            } else {
              console.log("⚠️ Translation minimal — skipping usage enforcement.");
            }
          } else {
            console.warn("⚠️ Translation returned empty or null. Continuing with original text.");
          }
        } catch (err) {
          console.error("❌ Translation failed:", err);
          // Continue with original text if translation fails
        }
      } else {
        console.log(`🟢 Skipping translation – already ${targetLanguageTag}`);
      }

      // —— Normalise whitespace and HTML entities
      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      previewText("🧠 GPT input preview", finalText);

      // —— GPT formatting
      await enforceGptRecipePolicy(uid);

      // Source language for prompt context:
      // if we translated, pass the detected source base; else pass the target base
      const sourceLangForPrompt = translationUsed ? (srcBase || "unknown") : (tgtBase || "en");

      const formattedRecipe = await generateFormattedRecipe(
        finalText,
        sourceLangForPrompt,
        targetFlutterLocale   // ensure labels & output in the app’s language
      );

      console.log("✅ GPT formatting complete.");
      await incrementGptRecipeUsage(uid);

      // —— Usage metrics (month bucket)
      try {
        const monthKey = dayjs().format("YYYY-MM");

        await admin.firestore().doc(`users/${uid}/aiUsage/usage`).set(
          {
            [monthKey]: admin.firestore.FieldValue.increment(1),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        if (translationUsed) {
          await admin.firestore().doc(`users/${uid}/translationUsage/usage`).set(
            {
              [monthKey]: admin.firestore.FieldValue.increment(1),
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
        console.log("📈 Synced usage metrics to Firestore");
      } catch (err) {
        console.warn("⚠️ Failed to sync usage metrics to Firestore:", err);
      }

      console.log(`🏁 Processing complete in ${Date.now() - start}ms`);

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,          // e.g. "pl", "es", "en"
        flutterLocale,             // detected source locale for reference
        translationUsed,
        targetLanguageTag,         // e.g. "pl" or "en-GB"
        targetFlutterLocale,       // e.g. "pl" or "en_GB" (matches Flutter)
        imageUrls,
        isTranslated: translationUsed,
        translatedFromLanguage: translationUsed ? detectedLanguage : null,
      };
    } catch (err: any) {
      console.error("❌ extractAndFormatRecipe failed:");
      console.error("📛 Error message:", err?.message || err);
      console.error("🧵 Stack trace:\n", err?.stack || "No stack trace");
      console.error("📥 Request data:", JSON.stringify(request.data, null, 2));

      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        `❌ Failed to process recipe: ${err?.message || "Unknown error"}`
      );
    } finally {
      // —— Always attempt to clean up uploaded images, success or fail
      try {
        await Promise.all((request.data?.imageUrls ?? []).map(deleteUploadedImage));
      } catch (e) {
        console.warn("⚠️ Failed to delete uploaded images in finally:", e);
      }
    }
  }
);