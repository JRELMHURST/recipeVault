import { TranslationServiceClient } from "@google-cloud/translate";

const translateClient = new TranslationServiceClient();

/**
 * Detects source language and translates input to British English ("en-GB").
 */
export async function translateToEnglish(
  text: string,
  projectId: string
): Promise<{
  translatedText: string;
  detectedLanguage: string;
  translationUsed: boolean;
}> {
  if (!text?.trim()) {
    throw new Error("❌ No text provided for translation.");
  }

  console.log(`📥 Input to translate (${text.length} chars):\n${text.slice(0, 300)}\n`);

  const [response] = await translateClient.translateText({
    parent: `projects/${projectId}/locations/global`,
    contents: [text],
    mimeType: "text/plain",
    targetLanguageCode: "en-GB", // 🇬🇧 force UK English
    // Let Google auto-detect the source language
  });

  const translation = response.translations?.[0];
  const translatedText = translation?.translatedText ?? text;
  const detectedLanguage = translation?.detectedLanguageCode ?? "unknown";

  const translationUsed = translatedText.trim() !== text.trim();

  console.log(`🌍 Detected language: ${detectedLanguage}`);
  console.log(`🔁 Translation applied: ${translationUsed}`);
  if (translationUsed) {
    console.log(`🔤 Translated output preview:\n${translatedText.slice(0, 300)}\n`);
  } else {
    console.log(`⚠️ No translation applied. Original and translated text may be identical.`);
  }

  return {
    translatedText,
    detectedLanguage,
    translationUsed,
  };
}