import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";

import { extractTextFromImages } from "./ocr";
import { detectLanguage } from "./detect";
import { translateToEnglish } from "./translate";
import { generateFormattedRecipe } from "./gpt_logic";
import { cleanText, previewText } from "./text_utils";

export const extractAndFormatRecipe = onCall(
  { region: "europe-west2" },
  async (request) => {
    const start = Date.now();
    const imageUrls: string[] = request.data?.imageUrls;

    // ✅ Fix: properly resolve project ID
    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      "";

    console.log(`🧭 Project ID used for translation: ${projectId}`);

    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing or invalid 'imageUrls' array"
      );
    }

    try {
      console.log(
        `📸 [${new Date().toISOString()}] Starting processing of ${imageUrls.length} image(s)...`
      );

      const ocrText = await extractTextFromImages(imageUrls);
      console.log(`📝 OCR result length: ${ocrText.length}`);
      previewText("🔎 Raw OCR text", ocrText);

      if (!ocrText.trim()) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "No text detected in provided images."
        );
      }

      const cleanInput = cleanText(ocrText);

      // 🌍 Detect language
      let detectedLanguage = "unknown";
      let confidence = 0;
      try {
        const detection = await detectLanguage(cleanInput, projectId);
        detectedLanguage = detection.languageCode;
        confidence = detection.confidence;
        console.log(
          `🌐 Detected language: ${detectedLanguage} (confidence: ${confidence})`
        );
        console.log(`✅ PRE-TRANSLATE CHECK complete`);
      } catch (err) {
        console.warn("⚠️ Language detection failed:", err);
      }

      // 🌐 Translate to en-GB if needed
      let translatedText = cleanInput;
      let translationUsed = false;

      try {
        if (true) {
          console.log(
            `🚧 Attempting translation from "${detectedLanguage}" → en-GB...`
          );
          const result = await translateToEnglish(
            cleanInput,
            detectedLanguage,
            projectId
          );

          if (!result?.trim()) {
            console.warn("⚠️ Translation returned empty result. Skipping.");
          } else if (result.trim() === cleanInput.trim()) {
            console.warn("⚠️ Translation identical to input. May have been skipped.");
          } else {
            translatedText = result;
            translationUsed = true;
            console.log(`✅ Translation applied. Length: ${translatedText.length}`);
            previewText("📝 Translated preview", translatedText);
          }
        }
      } catch (err) {
        console.error("❌ Translation failed. Using original OCR text:", err);
      }

      const usedText =
        translationUsed &&
        translatedText.trim().length > 20 &&
        translatedText.trim() !== ocrText.trim()
          ? translatedText
          : ocrText;

      if (translationUsed && usedText === ocrText) {
        console.warn(
          "⚠️ Translation marked as used, but fallback triggered due to similarity."
        );
      }

      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      previewText("🧠 GPT input preview", finalText);

      const formattedRecipe = await generateFormattedRecipe(
        finalText,
        detectedLanguage
      );
      console.log("✅ GPT formatting complete.");

      // 🧹 Delete uploaded images
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
      throw new functions.https.HttpsError("internal", "Failed to process recipe.");
    }
  }
);