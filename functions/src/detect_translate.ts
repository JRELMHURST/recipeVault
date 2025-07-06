import { TranslationServiceClient } from "@google-cloud/translate";

const translateClient = new TranslationServiceClient();

/**
 * Detects the source language and translates to British English ("en-GB").
 */
export async function translateToEnglish(text: string, projectId: string) {
  if (!text || text.trim().length === 0) {
    throw new Error("Empty text provided for translation.");
  }

  const [translationResponse] = await translateClient.translateText({
    parent: `projects/${projectId}/locations/global`,
    contents: [text],
    mimeType: "text/plain",
    targetLanguageCode: "en-GB", // 🇬🇧 British English
    // No sourceLanguageCode → allow Google to auto-detect
  });

  const translation = translationResponse.translations?.[0];

  const translatedText = translation?.translatedText ?? text;
  const detectedLanguage = translation?.detectedLanguageCode ?? "unknown";

  const translationUsed =
    detectedLanguage.toLowerCase() !== "en" &&
    translatedText.trim() !== text.trim();

  console.log(`🌍 Detected Language: ${detectedLanguage}`);
  console.log(`🔁 Translation used: ${translationUsed}`);
  if (translationUsed) {
    console.log(`🔤 Translated Text Preview:\n${translatedText.slice(0, 300)}\n`);
  }

  return {
    translatedText,
    detectedLanguage,
    translationUsed,
  };
}