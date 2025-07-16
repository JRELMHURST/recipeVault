import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";

import { extractTextFromImages } from "./ocr.js";
import { detectLanguage } from "./detect.js";
import { translateToEnglish } from "./translate.js";
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

export const extractAndFormatRecipe = onCall(
  {
    region: "europe-west2",
    secrets: [REVENUECAT_SECRET_KEY, OPENAI_API_KEY],
  },
  async (request: CallableRequest<{ imageUrls: string[] }>) => {
    const start = Date.now();
    const imageUrls = request.data?.imageUrls;

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      "";

    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new HttpsError("invalid-argument", "Missing or invalid 'imageUrls' array");
    }

    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const tier = await getResolvedTier(uid);
    console.log(`🎟️ Subscription tier resolved as: ${tier}`);

    try {
      console.log(`📸 Starting processing of ${imageUrls.length} image(s)...`);

      const ocrText = await extractTextFromImages(imageUrls);
      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }

      const cleanInput = cleanText(ocrText);
      previewText("🔎 Raw OCR text", ocrText);

      let detectedLanguage = "unknown";
      let confidence = 0;

      try {
        const detection = await detectLanguage(cleanInput, projectId);
        detectedLanguage = detection.languageCode;
        confidence = detection.confidence;
        console.log(`🌐 Detected language: ${detectedLanguage} (confidence: ${confidence})`);
      } catch (err) {
        console.warn("⚠️ Language detection failed:", err);
      }

      let translatedText = cleanInput;
      let translationUsed = false;

      const isLikelyEnglish =
        detectedLanguage.toLowerCase() === "en" ||
        detectedLanguage.toLowerCase().startsWith("en-");

      if (!isLikelyEnglish) {
        try {
          console.log(`🚧 Translating from "${detectedLanguage}" → en-GB...`);
          const result = await translateToEnglish(cleanInput, detectedLanguage, projectId);

          if (result?.trim()) {
            const cleanedOriginal = cleanText(cleanInput);
            const cleanedTranslated = cleanText(result.trim());

            if (cleanedOriginal !== cleanedTranslated) {
              await enforceTranslationPolicy(uid);

              translatedText = result.trim();
              translationUsed = true;
              previewText("📝 Translated preview", translatedText);
            } else {
              console.log("⚠️ Translated text is too similar to original — skipping translation usage.");
            }
          } else {
            console.warn("⚠️ Translation returned empty or null. Skipping.");
          }
        } catch (err) {
          console.error("❌ Translation failed:", err);
        }
      } else {
        console.log("🟢 Skipping translation – already English");
      }

      if (translationUsed) {
        await incrementTranslationUsage(uid);
      }

      const usedText = translationUsed ? translatedText : cleanInput;

      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      previewText("🧠 GPT input preview", finalText);

      await enforceGptRecipePolicy(uid);

      const formattedRecipe = await generateFormattedRecipe(
        finalText,
        translationUsed ? detectedLanguage : "en"
      );
      console.log("✅ GPT formatting complete.");

      await incrementGptRecipeUsage(uid);

      await Promise.all(imageUrls.map(deleteUploadedImage));
      console.log(`🏁 Processing complete in ${Date.now() - start}ms`);

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,
        translationUsed,
        targetLanguage: "en-GB",
        imageUrls,
        isTranslated: translationUsed,
        translatedFromLanguage: translationUsed ? detectedLanguage : null,
      };
    } catch (err: any) {
      console.error("❌ extractAndFormatRecipe failed:");
      console.error("📛 Error message:", err?.message || err);
      console.error("🧵 Stack trace:\n", err?.stack || "No stack trace");
      console.error("📥 Request data:", JSON.stringify(request.data, null, 2));

      if (err instanceof HttpsError) {
        throw err;
      }

      throw new HttpsError("internal", "An unexpected error occurred while processing your recipe.");
    }
  }
);