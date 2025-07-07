import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";

import { extractTextFromImages } from "./ocr";
import { detectLanguage } from "./detect";
import { translateToEnglish } from "./translate";
import { generateFormattedRecipe } from "./gpt_logic";
import { cleanText, previewText } from "./text_utils";
import {
  enforceTranslationPolicy,
  incrementTranslationUsage,
} from "./translation_sub_limits";
import {
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
} from "./gpt_recipe_sub_limits";

const firestore = getFirestore();

export const extractAndFormatRecipe = onCall(
  { region: "europe-west2" },
  async (request: CallableRequest<{ imageUrls: string[] }>) => {
    const start = Date.now();
    const imageUrls = request.data?.imageUrls;

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      "";

    console.log(`🧭 Project ID used for translation: ${projectId}`);

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
      console.log(`📝 OCR result length: ${ocrText.length}`);
      previewText("🔎 Raw OCR text", ocrText);

      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }

      const cleanInput = cleanText(ocrText);

      // 🌍 Language detection
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

      // 🌐 Translate if needed
      let translatedText = cleanInput;
      let translationUsed = false;

      const isLikelyEnglish =
        detectedLanguage.toLowerCase() === "en" ||
        detectedLanguage.toLowerCase().startsWith("en-");

      const userDoc = await firestore.collection("users").doc(uid).get();
      const tier = userDoc.data()?.tier || "taster";

      if (!isLikelyEnglish) {
        await enforceTranslationPolicy(uid, tier);

        try {
          console.log(`🚧 Translating from "${detectedLanguage}" → en-GB...`);
          const result = await translateToEnglish(cleanInput, detectedLanguage, projectId);

          if (!result?.trim()) {
            console.warn("⚠️ Translation returned empty result. Skipping.");
          } else {
            translatedText = result.trim();
            translationUsed = true;
            console.log(`✅ Translation applied. Length: ${translatedText.length}`);
            previewText("📝 Translated preview", translatedText);
          }
        } catch (err) {
          console.error("❌ Translation failed. Using original OCR text:", err);
        }
      } else {
        console.log("🟢 Skipping translation – already English");
      }

      // ✅ Discard if translation was unnecessary
      const original = ocrText.trim();
      const translated = translatedText.trim();

      if (
        translationUsed &&
        (translated === original || detectedLanguage.toLowerCase().startsWith("en"))
      ) {
        translationUsed = false;
        console.warn("⚠️ Translation discarded – already English or unchanged.");
      }

      if (translationUsed) {
        await incrementTranslationUsage(uid, tier);
      }

      const usedText = translationUsed ? translated : original;

      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      previewText("🧠 GPT input preview", finalText);

      // 🚧 Enforce GPT recipe generation limit
      await enforceGptRecipePolicy(uid, tier);

      const formattedRecipe = await generateFormattedRecipe(finalText, detectedLanguage);
      console.log("✅ GPT formatting complete.");

      // ✅ Increment GPT usage after success
      await incrementGptRecipeUsage(uid, tier);

      // 🔍 Debug info
      console.log("🧪 Final debug result:", {
        detectedLanguage,
        translationUsed,
        ocrSnippet: ocrText.slice(0, 100),
        translatedSnippet: translatedText.slice(0, 100),
        isDifferent: translatedText.trim() !== ocrText.trim(),
      });

      // 🧹 Clean up uploaded images
      await Promise.all(
        imageUrls.map(async (url) => {
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
        })
      );

      console.log(`🏁 Processing complete in ${Date.now() - start}ms`);

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,
        translationUsed,
        targetLanguage: "en-GB",
        imageUrls,
      };
    } catch (err) {
      console.error("❌ extractAndFormatRecipe failed:", err);
      throw new HttpsError("internal", "Failed to process recipe.");
    }
  }
);