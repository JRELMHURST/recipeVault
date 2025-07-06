import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";
import { extractTextFromImages } from "./ocr";
import { translateToEnglish } from "./detect_translate";
import { generateFormattedRecipe } from "./gpt_logic";

initializeApp();

export const extractAndFormatRecipe = onCall(
  { region: "europe-west2" },
  async (request) => {
    const imageUrls: string[] = request.data?.imageUrls;

    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing or invalid 'imageUrls' array"
      );
    }

    try {
      console.log(`🔍 Running OCR for ${imageUrls.length} image(s)...`);
      const ocrText = await extractTextFromImages(imageUrls);

      if (!ocrText || ocrText.trim().length === 0) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "No text detected in images."
        );
      }

      console.log("🌐 Attempting translation to English...");
      const { translatedText, detectedLanguage, translationUsed } =
        await translateToEnglish(ocrText, process.env.GOOGLE_CLOUD_PROJECT || "");

      // ✅ DEBUG: Language detection and translation preview
      console.log(`🌍 Detected Language: ${detectedLanguage}`);
      console.log(`🔁 Translation used: ${translationUsed}`);
      console.log("🗣️ Translated preview:\n", translatedText.slice(0, 200));

      const finalText = decode(
        translatedText.trim() !== "" ? translatedText : ocrText
      )
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      console.log("📦 Final GPT input preview:\n", finalText.slice(0, 300));
      const formattedRecipe = await generateFormattedRecipe(finalText, detectedLanguage);

      // 🔥 Cleanup: delete uploaded images
      await Promise.all(
        imageUrls.map(async (url) => {
          try {
            const match = url.match(/o\/(.+?)\?.*/);
            if (!match || match.length < 2) return;

            const path = decodeURIComponent(match[1]);
            await getStorage().bucket().file(path).delete();
            console.log(`🗑️ Deleted image: ${path}`);
          } catch (err) {
            console.error("⚠️ Image deletion failed:", err);
          }
        })
      );

      return {
        formattedRecipe,
        detectedLanguage,
        targetLanguage: "en-GB",
        translationUsed,
        originalText: ocrText,
      };
    } catch (err) {
      console.error("❌ Failed to process recipe:", err);
      throw new functions.https.HttpsError("internal", "Failed to process recipe.");
    }
  }
);