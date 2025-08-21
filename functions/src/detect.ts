import "./firebase.js";
import { TranslationServiceClient } from "@google-cloud/translate";

const client = new TranslationServiceClient();

/** 🔡 Unicode-friendly cleanup: keep diacritics, normalise, collapse whitespace */
function cleanText(input: string): string {
  return input
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "") // zero-width
    .replace(/\r/g, "")
    .replace(/[ \t]+\n/g, "\n") // strip trailing spaces before newline
    .replace(/\s{2,}/g, " ") // collapse double spaces
    .trim();
}

/** ✂️ Limit to GCP API max (5k chars) */
function truncate(input: string, max = 5000): string {
  return input.length > max ? input.slice(0, max) : input;
}

/** 🌍 Map GCP language codes → Flutter locale tag */
function mapToFlutterLocale(code: string): string {
  const base = code.toLowerCase();

  const supported = new Set([
    "en", "en-gb", "bg", "cs", "da", "de", "el",
    "es", "fr", "ga", "it", "nl", "pl", "cy",
  ]);

  // ✅ If exact match or BCP-47 style (xx-XX)
  if (supported.has(base) || /^[a-z]{2}-[a-z]{2}$/i.test(base)) {
    return base.replace("-", "_");
  }

  // 🔙 Fallback: always safe
  return "en_GB";
}

/**
 * 🧪 Detect language using Google Cloud Translate API
 * @returns { languageCode, confidence, flutterLocale }
 *
 * ⚠️ No quota enforcement here — usage is billed at GPT step.
 */
export async function detectLanguage(
  text: string,
  projectId?: string
): Promise<{
  languageCode: string;
  confidence: number;
  flutterLocale: string;
}> {
  if (!text?.trim()) {
    throw new Error("❌ detectLanguage: No text provided.");
  }

  const pid =
    projectId ||
    process.env.GCLOUD_PROJECT ||
    process.env.FUNCTIONS_PROJECT_ID ||
    process.env.GCP_PROJECT ||
    "";
  if (!pid) {
    throw new Error("❌ detectLanguage: No projectId available for Translate API.");
  }

  const cleaned = truncate(cleanText(text));
  console.log(
    `🔍 Language detection → original=${text.length} chars, cleaned=${cleaned.length} chars`
  );

  try {
    const [response] = await client.detectLanguage({
      parent: `projects/${pid}/locations/global`,
      content: cleaned,
      mimeType: "text/plain",
    });

    const language = response.languages?.[0];
    const languageCode = (language?.languageCode || "unknown").toLowerCase();
    const confidence = language?.confidence ?? 0;
    const flutterLocale = mapToFlutterLocale(languageCode);

    if (confidence < 0.5) {
      console.warn("⚠️ detectLanguage: Low confidence result", {
        languageCode,
        confidence,
      });
    }

    return { languageCode, confidence, flutterLocale };
  } catch (err) {
    console.error("❌ detectLanguage failed:", err);
    return { languageCode: "unknown", confidence: 0, flutterLocale: "en_GB" };
  }
}