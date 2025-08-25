import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";

import { extractTextFromImages } from "./ocr.js";
import { detectLanguage } from "./detect.js";
import { translateText } from "./translate.js";
import { generateFormattedRecipe } from "./gpt_logic.js";
import { getResolvedTier } from "./usage_service.js";

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
    if (!match?.[1]) return;
    const path = decodeURIComponent(match[1]);
    const file = getStorage().bucket().file(path);
    const [exists] = await file.exists();
    if (exists) {
      await file.delete();
      console.info({ msg: "🗑️ Deleted uploaded image", path });
    }
  } catch (err) {
    console.warn("⚠️ Error deleting image", url, err);
  }
}

/* ─────────── Retry util ─────────── */
async function withRetries<T>(
  fn: () => Promise<T>,
  retries = 3,
  baseDelayMs = 500
): Promise<T> {
  let lastErr: any;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (attempt === retries) break;
      const backoff = baseDelayMs * Math.pow(2, attempt);
      console.warn(
        `[extractAndFormatRecipe] ⚠️ Attempt ${attempt + 1} failed, retrying in ${backoff}ms…`,
        err
      );
      await new Promise((res) => setTimeout(res, backoff));
    }
  }
  throw lastErr;
}

/* ─────────── Main Cloud Function ─────────── */
export const extractAndFormatRecipe = onCall(
  {
    region: "europe-west2",
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 300, // ⏱️ extend timeout (default = 60)
    memory: "1GiB",      // 💾 increase memory for OCR + GPT
      cpu: 2,              // ⚡ more CPU = faster OCR/JSON parsing
  minInstances: 1,     // 🔥 no cold starts on first hit
  },
  async (request: CallableRequest<{
    imageUrls: string[];
    targetLanguage?: string;
    targetRegion?: string;
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
    console.info({ msg: "🎟️ Subscription tier", uid, tier });

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      process.env.GCP_PROJECT ||
      "";
    if (!projectId) throw new HttpsError("failed-precondition", "No project ID available.");

    // —— Target locale
    const targetLanguage = (request.data?.targetLanguage || "en").toLowerCase();
    const targetRegion = (request.data?.targetRegion || "GB") || undefined;
    const targetLanguageTag = toBcp47(targetLanguage, targetRegion);
    const targetFlutterLocale = toFlutterLocaleTag(targetLanguage, targetRegion);

    try {
      console.info({ msg: "📸 Starting processing", uid, images: imageUrls.length });

      // —— OCR (consumes imageUsage internally)
      const ocrText = await withRetries(() => extractTextFromImages(uid, imageUrls));
      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }
      const cleanInput = ocrText.replace(/[ \t]+\n/g, "\n").trim();
      console.info({ msg: "🔎 OCR complete", uid, chars: cleanInput.length });

      // —— Language detection
      let detectedLanguage = "unknown";
      let confidence = 0;
      let flutterLocale = "en_GB";
      try {
        const detection = await withRetries(() => detectLanguage(cleanInput, projectId));
        detectedLanguage = detection.languageCode || "unknown";
        confidence = detection.confidence ?? 0;
        flutterLocale = detection.flutterLocale || "en_GB";
        console.info({ msg: "🌐 Language detected", detectedLanguage, confidence, flutterLocale });
      } catch (err) {
        console.warn("⚠️ Language detection failed", err);
      }

      // —— Decide if translation is needed
      const srcBase = normalizeLangBase(detectedLanguage);
      const tgtBase = normalizeLangBase(targetLanguage);
      const alreadyTarget = srcBase && tgtBase && srcBase === tgtBase;

      let usedText = cleanInput;
      let translationUsed = false;
      let usageKind: "recipeUsage" | "translatedRecipeUsage" = "recipeUsage";

      if (srcBase && !alreadyTarget) {
        try {
          const translated = await withRetries(() =>
            translateText(cleanInput, detectedLanguage, targetLanguageTag, projectId)
          );
          const cleanedTranslated = (translated || "").trim();
          if (cleanedTranslated) {
            usedText = cleanedTranslated;
            translationUsed = true;
            usageKind = "translatedRecipeUsage";
            console.info({ msg: "✅ Translation successful", from: detectedLanguage, to: targetLanguageTag });
          } else {
            console.warn("⚠️ Empty translation. Falling back to original text.");
          }
        } catch (err) {
          console.warn("⚠️ Translation failed. Falling back to original text.", err);
        }
      }

      // —— GPT formatting (consumes recipeUsage/translatedRecipeUsage)
      const finalText = decode(usedText.trim());
      const formattedRecipe = await withRetries(() =>
        generateFormattedRecipe(
          uid,
          finalText,
          translationUsed ? (srcBase || "unknown") : (tgtBase || "en"),
          targetFlutterLocale,
          usageKind
        )
      );

      console.info({ msg: "🏁 Recipe processed", uid, ms: Date.now() - start });

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
      console.error("❌ extractAndFormatRecipe failed", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        `❌ Failed to process recipe: ${err?.message || "Unknown error"}`
      );
    } finally {
      // Always delete uploads
      await Promise.all((request.data?.imageUrls ?? []).map(deleteUploadedImage));
    }
  }
);