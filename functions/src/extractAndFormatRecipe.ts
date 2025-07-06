import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";

import { extractTextFromImages } from "./ocr";
import { translateToEnglish } from "./translate_to_english";
import { generateFormattedRecipe } from "./gpt_logic";

initializeApp();

export const extractAndFormatRecipe = onCall(
  { region: "europe-west2" },
  async (request) => {
    const imageUrls: string[] = request.data?.imageUrls;
    const projectId = process.env.GOOGLE_CLOUD_PROJECT || "";

    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing or invalid 'imageUrls' array"
      );
    }

    try {
      console.log(`🔍 OCR: Processing ${imageUrls.length} image(s)...`);
      const ocrText = await extractTextFromImages(imageUrls);
      console.log(`📝 OCR result length: ${ocrText.length}`);

      if (!ocrText.trim()) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "No text detected in provided images."
        );
      }

      console.log("🌐 Translation: Detecting and converting to en-GB...");
      const { translatedText, detectedLanguage, translationUsed } =
        await translateToEnglish(ocrText, projectId);

      console.log("📋 Translation Summary:", {
        detectedLanguage,
        translationUsed,
        translatedTextPreview: translatedText.slice(0, 200),
      });

      // ✅ Choose which version to send to GPT
      const usedText = translationUsed ? translatedText : ocrText;

      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      console.log("🧠 GPT input preview:", finalText.slice(0, 300));
      const formattedRecipe = await generateFormattedRecipe(finalText, detectedLanguage);

      console.log("✅ GPT formatting complete.");

      // 🔥 Cleanup uploaded image files from Storage
      await Promise.all(
        imageUrls.map(async (url) => {
          try {
            const match = url.match(/o\/(.+?)\?.*/);
            if (!match?.[1]) return;

            const path = decodeURIComponent(match[1]);
            await getStorage().bucket().file(path).delete();
            console.log(`🗑️ Deleted uploaded image: ${path}`);
          } catch (err) {
            console.warn("⚠️ Error deleting image:", err);
          }
        })
      );

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,
        translationUsed,
        targetLanguage: "en-GB",
        imageUrls,
      };
    } catch (err) {
      console.error("❌ Recipe processing failed:", err);
      throw new functions.https.HttpsError("internal", "Failed to process recipe.");
    }
  }
);