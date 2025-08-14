import { TranslationServiceClient } from "@google-cloud/translate";
import "./firebase.js";

const client = new TranslationServiceClient();

/**
 * Lightly cleans OCR text while preserving structure and culinary terms.
 */
function cleanText(input: string): string {
  return input
    .replace(/[^\w\s.,:;()&%/-]/g, "") // Allow common punctuation and symbols
    .replace(/\s{2,}/g, " ") // Collapse extra spaces
    .trim();
}

/**
 * Translates provided text from a detected language to a target language (e.g., "en-GB", "pl", "de").
 * Falls back gracefully if translation fails.
 */
export async function translateText(
  text: string,
  sourceLanguage: string,
  targetLanguage: string, // e.g. "en-GB", "pl", "de"
  projectId: string
): Promise<string> {
  if (!text?.trim()) {
    throw new Error("❌ No text provided for translation.");
  }

  const cleanedText = cleanText(text);

  console.log(`🔤 Translating from "${sourceLanguage}" → "${targetLanguage}"`);
  console.log(
    `📏 Original length: ${text.length}, Cleaned: ${cleanedText.length}`
  );
  console.log(`🧪 Preview:\n${cleanedText.slice(0, 300)}\n`);

  try {
    const [response] = await client.translateText({
      parent: `projects/${projectId}/locations/global`,
      contents: [cleanedText],
      mimeType: "text/plain",
      sourceLanguageCode: sourceLanguage,
      targetLanguageCode: targetLanguage,
    });

    const translated =
      response.translations?.[0]?.translatedText || cleanedText;

    console.log(`✅ Translation complete.`);
    console.log(`🧾 Result preview:\n${translated.slice(0, 300)}\n`);

    if (translated.trim() === cleanedText.trim()) {
      console.warn(
        "⚠️ Translation output is identical to input. Translation may have been skipped."
      );
    }

    return translated;
  } catch (err) {
    console.error("❌ Translation API failed:", err);
    return cleanedText; // Fallback to cleaned input
  }
}