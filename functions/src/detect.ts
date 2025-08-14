import "./firebase.js";
import { TranslationServiceClient } from "@google-cloud/translate";

const client = new TranslationServiceClient();

// Keep punctuation & units useful for recipes; strip weird glyphs.
function cleanText(input: string): string {
  return input
    .replace(/[^\w\s.,:;()&%/-]/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

// Truncate to keep request size sane (Google limits + cost).
function truncate(input: string, max = 5000): string {
  return input.length > max ? input.slice(0, max) : input;
}

// Map GCP language codes to your Flutter supported locales
// Prefer British English as your default. Add more mappings as needed.
function mapToFlutterLocale(code: string): string {
  const base = code.toLowerCase(); // e.g. "en", "pl", "ga"

  // Full matches you listed in l10n.yaml
  const exact = new Set([
    "en", "en-gb", "bg", "cs", "da", "de", "el", "es", "fr", "ga", "it", "nl", "pl", "cy",
  ]);

  // If Google returns a regional subtag, passthrough (we’ll normalise underscore later)
  if (exact.has(base) || /^[a-z]{2}(-[a-z]{2})$/i.test(code)) {
    return base.replace("-", "_"); // Flutter likes underscores
  }

  // Fallbacks: coerce base languages to your supported set
  switch (base) {
    case "en":
      return "en_GB"; // your preferred English
    case "pt":
      return "pt_PT"; // example if you later add PT; otherwise fall through
    default:
      return "en_GB"; // safe default
  }
}

export async function detectLanguage(
  text: string,
  projectId?: string
): Promise<{
  languageCode: string;      // e.g. "pl", "en", "fr"
  confidence: number;        // 0..1
  flutterLocale: string;     // e.g. "pl", "en_GB", "fr"
}> {
  if (!text?.trim()) {
    throw new Error("❌ No text provided for language detection.");
  }

  const pid =
    projectId ||
    process.env.GCLOUD_PROJECT ||
    process.env.FUNCTIONS_PROJECT_ID ||
    process.env.GCP_PROJECT ||
    "";

  if (!pid) {
    throw new Error("❌ No projectId available for Translate API.");
  }

  const cleaned = truncate(cleanText(text));

  console.log(
    `🔍 Detecting language: original=${text.length} chars, cleaned=${cleaned.length} chars`
  );
  console.log(`🧪 Sample:\n${cleaned.slice(0, 300)}\n`);

  try {
    const [response] = await client.detectLanguage({
      parent: `projects/${pid}/locations/global`,
      content: cleaned,
      mimeType: "text/plain",
    });

    const language = response.languages?.[0];
    const languageCode = (language?.languageCode || "unknown").toLowerCase(); // e.g. "pl"
    const confidence = language?.confidence ?? 0;

    if (confidence < 0.5) {
      console.warn("⚠️ Low confidence in language detection.");
    }

    const flutterLocale = mapToFlutterLocale(languageCode);

    console.log(`🌍 Detected: ${languageCode} (conf=${confidence}) → flutter=${flutterLocale}`);

    return { languageCode, confidence, flutterLocale };
  } catch (err) {
    console.error("❌ Language detection failed:", err);
    return { languageCode: "unknown", confidence: 0, flutterLocale: "en_GB" };
  }
}