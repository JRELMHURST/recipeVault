import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";

import { extractTextFromImages } from "./ocr.js";
import { detectLanguage } from "./detect.js";
import { translateText } from "./translate.js";
import { generateFormattedRecipe } from "./gpt_logic.js";
import {
  getResolvedTier,
  enforceTranslationPolicy,
  incrementMonthlyUsage,
  enforceGptRecipePolicy,
} from "./usage_service.js";

// 🔑 Secrets
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
  { secrets: [REVENUECAT_SECRET_KEY, OPENAI_API_KEY] },
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

    // 🔐 HARD GATE before expensive work
    const tier = await getResolvedTier(uid); // 'home_chef' | 'master_chef' | 'none'
    if (tier === "none") {
      throw new HttpsError(
        "permission-denied",
        "A free trial or subscription is required to process screenshots."
      );
    }
    console.log(`🎟️ Subscription tier resolved as: ${tier}`);

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      process.env.GCP_PROJECT ||
      "";
    if (!projectId) {
      throw new HttpsError("failed-precondition", "No project ID available.");
    }

    // —— Target locale from frontend
    const targetLanguage = (request.data?.targetLanguage || "en").toLowerCase();
    const targetRegion = (request.data?.targetRegion || "GB") || undefined;
    const targetLanguageTag = toBcp47(targetLanguage, targetRegion);
    const targetFlutterLocale = toFlutterLocaleTag(targetLanguage, targetRegion);

    try {
      console.log(`📸 Starting processing of ${imageUrls.length} image(s)...`);

      // —— OCR
      const ocrText = await extractTextFromImages(imageUrls);
      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }
      const cleanInput = ocrText.replace(/[ \t]+\n/g, "\n").trim();
      console.log("🔎 OCR complete");

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
          const cleanedTranslated = (translated || "").trim();
          if (cleanedTranslated) {
            usedText = cleanedTranslated;
            translationUsed = true;

            // ✅ Enforce + count via usage service
            await enforceTranslationPolicy(uid);
            await incrementMonthlyUsage(uid, "translationUsage");

            console.log("✅ Translation successful & usage incremented");
          } else {
            console.warn("⚠️ Translation returned empty. Continuing with original text.");
          }
        } catch (err) {
          console.error("❌ Translation failed:", err);
        }
      } else {
        console.log(`🟢 Skipping translation – already ${targetLanguageTag}`);
      }

      // —— GPT formatting (enforce policy first)
      await enforceGptRecipePolicy(uid);

      const finalText = decode(usedText.trim());
      const formattedRecipe = await generateFormattedRecipe(
        finalText,
        translationUsed ? (srcBase || "unknown") : (tgtBase || "en"),
        targetFlutterLocale
      );

      await incrementMonthlyUsage(uid, "aiUsage");
      console.log("✅ GPT formatting complete & usage incremented");

      console.log(`🏁 Processing complete in ${Date.now() - start}ms`);

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,          // e.g. "pl", "es", "en"
        flutterLocale,             // detected source locale for reference
        translationUsed,
        targetLanguageTag,         // e.g. "pl" or "en-GB"
        targetFlutterLocale,       // e.g. "pl" or "en_GB"
        imageUrls,
        isTranslated: translationUsed,
        translatedFromLanguage: translationUsed ? detectedLanguage : null,
        tier,
      };
    } catch (err: any) {
      console.error("❌ extractAndFormatRecipe failed:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", `❌ Failed to process recipe: ${err?.message || "Unknown error"}`);
    } finally {
      // Always delete uploads
      try {
        await Promise.all((request.data?.imageUrls ?? []).map(deleteUploadedImage));
      } catch (e) {
        console.warn("⚠️ Failed to delete uploaded images:", e);
      }
    }
  }
);