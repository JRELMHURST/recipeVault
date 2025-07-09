import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";
import fetch from "node-fetch";

import { extractTextFromImages } from "./ocr";
import { detectLanguage } from "./detect";
import { translateToEnglish } from "./translate";
import { generateFormattedRecipe } from "./gpt_logic";
import { cleanText, previewText } from "./text_utils";
import {
  enforceTranslationPolicy,
  incrementTranslationUsage,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
} from "./policy";

async function fetchRevenueCatTier(uid: string): Promise<string> {
  try {
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
      headers: {
        Authorization: `Bearer ${process.env.REVENUECAT_SECRET_KEY}`,
      },
    });

    if (!response.ok) {
      console.warn("⚠️ Failed to fetch RevenueCat subscriber info");
      return "taster";
    }

    const json = await response.json();
    const entitlements = json?.subscriber?.entitlements;

    if (entitlements?.masterChef?.is_active) return "masterChef";
    if (entitlements?.homeChef?.is_active) return "homeChef";
    return "taster";
  } catch (err) {
    console.error("❌ RevenueCat API error:", err);
    return "taster";
  }
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

export const extractAndFormatRecipe = onCall(
  { region: "europe-west2" },
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

    try {
      console.log(`📸 Starting processing of ${imageUrls.length} image(s)...`);

      const ocrText = await extractTextFromImages(imageUrls);
      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }

      const cleanInput = cleanText(ocrText);
      previewText("🔎 Raw OCR text", ocrText);

      // 🌍 Detect language
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

      // 🔐 Check subscription tier
      const tier = await fetchRevenueCatTier(uid);

      // 🔄 Translation logic
      let translatedText = cleanInput;
      let translationUsed = false;

      const isLikelyEnglish =
        detectedLanguage.toLowerCase() === "en" ||
        detectedLanguage.toLowerCase().startsWith("en-");

      if (!isLikelyEnglish) {
        await enforceTranslationPolicy(uid, tier);
        try {
          console.log(`🚧 Translating from "${detectedLanguage}" → en-GB...`);
          const result = await translateToEnglish(cleanInput, detectedLanguage, projectId);

          if (result?.trim() && result.trim() !== cleanInput.trim()) {
            translatedText = result.trim();
            translationUsed = true;
            previewText("📝 Translated preview", translatedText);
          } else {
            console.warn("⚠️ Translation returned empty or identical result. Skipping.");
          }
        } catch (err) {
          console.error("❌ Translation failed:", err);
        }
      } else {
        console.log("🟢 Skipping translation – already English");
      }

      if (translationUsed) {
        await incrementTranslationUsage(uid, tier);
      }

      const usedText = translationUsed ? translatedText : cleanInput;

      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      previewText("🧠 GPT input preview", finalText);

      // ✅ GPT limit check
      await enforceGptRecipePolicy(uid, tier);

      const formattedRecipe = await generateFormattedRecipe(finalText, detectedLanguage);
      console.log("✅ GPT formatting complete.");

      await incrementGptRecipeUsage(uid, tier);

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
    } catch (err) {
      console.error("❌ extractAndFormatRecipe failed:", err);
      throw new HttpsError("internal", "Failed to process recipe.");
    }
  }
);