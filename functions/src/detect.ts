import "./firebase.js";
import { TranslationServiceClient } from "@google-cloud/translate";

const client = new TranslationServiceClient();

/**
 * ✅ Soft cleans OCR text to preserve food-related structure
 */
function cleanText(input: string): string {
  return input
    .replace(/[^\w\s.,:;()&%/-]/g, '')   // Allow common punctuation and food units
    .replace(/\s{2,}/g, ' ')             // Collapse extra spaces
    .trim();
}

/**
 * 🌐 Detects the language of provided text using Google Translate API
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
  console.log(`🔍 Detecting language for ${text.length} original chars, ${cleanedText.length} cleaned chars`);
  console.log(`🧪 Sample preview:\n${cleanedText.slice(0, 300)}\n`);

  try {
    const [response] = await client.detectLanguage({
      parent: `projects/${projectId}/locations/global`,
      content: cleanedText,
      mimeType: "text/plain",
    });

    const language = response.languages?.[0];
    const languageCode = language?.languageCode || "unknown";
    const confidence = language?.confidence ?? 0;

    console.log(`🌍 Language detected: ${languageCode}`);
    console.log(`📈 Confidence score: ${confidence}`);

    if (confidence < 0.5) {
      console.warn("⚠️ Low confidence in language detection. Consider fallback handling.");
    }

    return { languageCode, confidence };
  } catch (err) {
    console.error("❌ Language detection failed:", err);
    return { languageCode: "unknown", confidence: 0 };
  }
}