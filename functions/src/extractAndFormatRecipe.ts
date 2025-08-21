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
  enforceAndConsume,
  incrementMonthlyUsage,
} from "./usage_service.js";

// 🔑 Secrets
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

/* ─────────── Helpers ─────────── */
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

/* ─────────── Main Cloud Function ─────────── */
export const extractAndFormatRecipe = onCall(
  { secrets: [OPENAI_API_KEY] },
  async (request: CallableRequest<{
    imageUrls: string[];
    targetLanguage?: string; // e.g. "pl", "en"
    targetRegion?: string;   // e.g. "GB", "PL"
  }>) => {
    const start = Date.now();

    // —— Validate
    const imageUrls = request.data?.imageUrls;
    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new HttpsError("invalid-argument", "Missing or invalid 'imageUrls' array.");
    }
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "User must be authenticated.");

    // 🔐 Subscription check
    const tier = await getResolvedTier(uid);
    if (tier === "none") {
      throw new HttpsError(
        "permission-denied",
        "✨ Unlock Chef Mode with the Home Chef or Master Chef plan!"
      );
    }
    console.log(`🎟️ Subscription tier: ${tier}`);

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      process.env.GCP_PROJECT ||
      "";
    if (!projectId) throw new HttpsError("failed-precondition", "No project ID available.");

    // —— Target locale
    const targetLanguage = (request.data?.targetLanguage || "en").toLowerCase();
    const targetRegion = (request.data?.targetRegion || "GB") || undefined;
    const targetLanguageTag = toBcp47(targetLanguage, targetRegion);     // e.g. en-GB
    const targetFlutterLocale = toFlutterLocaleTag(targetLanguage, targetRegion); // e.g. en_GB

    try {
      console.log(`📸 Starting processing of ${imageUrls.length} image(s)...`);

      // —— OCR (helper already enforces imageUsage transactionally)
      const ocrText = await extractTextFromImages(uid, imageUrls);
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
          `🌐 Detected: ${detectedLanguage} (conf: ${confidence}) → flutterLocale: ${flutterLocale}`
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
      let usageKind: "recipeUsage" | "translatedRecipeUsage" = "recipeUsage";

      if (!srcBase) {
        console.log("🤷 Detection unknown — skipping translation.");
        await enforceAndConsume(uid, "recipeUsage", 1);
      } else if (!alreadyTarget) {
        // 🚦 Transactionally consume 1 translated recipe card credit
        await enforceAndConsume(uid, "translatedRecipeUsage", 1);
        usageKind = "translatedRecipeUsage";

        try {
          console.log(`🚧 Translating "${detectedLanguage}" → ${targetLanguageTag}...`);
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
            console.log("✅ Translation successful");
          } else {
            console.warn("⚠️ Translation returned empty. Continuing with original text.");
            // Refund translated recipe card credit
            await incrementMonthlyUsage(uid, "translatedRecipeUsage", -1).catch(() => {});
            // Instead consume a normal recipe credit
            await enforceAndConsume(uid, "recipeUsage", 1);
            usageKind = "recipeUsage";
          }
        } catch (err) {
          // Refund credit on failure
          try { await incrementMonthlyUsage(uid, "translatedRecipeUsage", -1); } catch {}
          throw err;
        }
      } else {
        console.log(`🟢 Skipping translation – already ${targetLanguageTag}`);
        await enforceAndConsume(uid, "recipeUsage", 1);
      }

      // —— GPT formatting
      const finalText = decode(usedText.trim());
      const formattedRecipe = await generateFormattedRecipe(
        uid,
        finalText,
        translationUsed ? (srcBase || "unknown") : (tgtBase || "en"),
        targetFlutterLocale,
        usageKind
      );

      console.log(`🏁 Done in ${Date.now() - start}ms`);

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,
        flutterLocale,
        translationUsed,
        targetLanguageTag,
        targetFlutterLocale,
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