import { TranslationServiceClient } from "@google-cloud/translate";

const client = new TranslationServiceClient();

/**
 * Soft cleans OCR text while preserving formatting and culinary context.
 */
function cleanText(input: string): string {
  return input
    .replace(/[^\w\s.,:;()&%/-]/g, '') // Preserve useful characters
    .replace(/\s{2,}/g, ' ') // Collapse multiple spaces
    .trim();
}

/**
 * Translates text from the detected source language to British English.
 */
export async function translateToEnglish(
  text: string,
  sourceLanguage: string,
  projectId: string
): Promise<string> {
  if (!text?.trim()) {
    throw new Error("❌ No text provided for translation.");
  }

  const cleanedText = cleanText(text);

  console.log(`🔤 Translating from ${sourceLanguage} → en-GB`);
  console.log(`📏 Original text length: ${text.length}, Cleaned: ${cleanedText.length}`);
  console.log(`🧪 Cleaned preview:\n${cleanedText.slice(0, 300)}\n`);

  try {
    const [response] = await client.translateText({
      parent: `projects/${projectId}/locations/global`,
      contents: [cleanedText],
      mimeType: "text/plain",
      sourceLanguageCode: sourceLanguage,
      targetLanguageCode: "en-GB",
    });

    const translated = response.translations?.[0]?.translatedText || cleanedText;

    console.log(`✅ Translation complete.`);
    console.log(`🧾 Translated preview:\n${translated.slice(0, 300)}\n`);

    if (translated.trim() === cleanedText.trim()) {
      console.warn("⚠️ Translated text is identical to input. Translation may have been skipped.");
    }

    return translated;
  } catch (err) {
    console.error("❌ Translation API failed:", err);
    return cleanedText; // Fallback to cleaned input
  }
}