import { TranslationServiceClient } from "@google-cloud/translate";

const client = new TranslationServiceClient();

/**
 * Soft cleans OCR text to preserve food-related structure.
 */
function cleanText(input: string): string {
  return input
    .replace(/[^\w\s.,:;()&%/-]/g, '') // Allow more useful characters
    .replace(/\s{2,}/g, ' ') // Collapse multiple spaces
    .trim();
}

/**
 * Detects the language of the provided text using Google Translate API.
 */
export async function detectLanguage(
  text: string,
  projectId: string
): Promise<{
  languageCode: string;
  confidence: number;
}> {
  if (!text?.trim()) {
    throw new Error("❌ No text provided for language detection.");
  }

  const cleanedText = cleanText(text);

  console.log(`🔍 Detecting language for text (${text.length} chars, cleaned: ${cleanedText.length})`);
  console.log(`🧪 Cleaned preview:\n${cleanedText.slice(0, 300)}\n`);

  try {
    const [response] = await client.detectLanguage({
      parent: `projects/${projectId}/locations/global`,
      content: cleanedText,
      mimeType: "text/plain",
    });

    const language = response.languages?.[0];

    const languageCode = language?.languageCode || "unknown";
    const confidence = language?.confidence ?? 0;

    console.log(`🌐 Detected language: ${languageCode}`);
    console.log(`📊 Confidence: ${confidence}`);

    if (confidence < 0.5) {
      console.warn("⚠️ Low confidence in language detection. Consider fallback or retry.");
    }

    return { languageCode, confidence };
  } catch (err) {
    console.error("❌ Language detection failed:", err);
    return { languageCode: "unknown", confidence: 0 };
  }
}