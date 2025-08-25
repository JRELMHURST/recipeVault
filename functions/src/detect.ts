// functions/src/detect_language.ts (or wherever you keep it)
import "./firebase.js";
import { TranslationServiceClient } from "@google-cloud/translate";

const client = new TranslationServiceClient();

/** 🔡 Unicode-friendly cleanup */
function cleanText(input: string): string {
  return input
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\r/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\s{2,}/g, " ")
    .trim();
}

/** ✂️ Limit to 5k (ample for Detect API) */
function truncate(input: string, max = 5000): string {
  return input.length > max ? input.slice(0, max) : input;
}

/** 🌍 Produce a hyphenated BCP‑47-ish tag like "en-GB" */
function toHyphenLocale(code: string): string {
  const lc = code.toLowerCase();
  const supported = new Set([
    "en", "en-gb", "bg", "cs", "da", "de", "el",
    "es", "fr", "ga", "it", "nl", "pl", "cy",
  ]);

  if (supported.has(lc)) return lc;                  // "en" | "en-gb" | ...
  if (/^[a-z]{2}-[a-z]{2}$/i.test(code)) return lc;  // keep structure

  // Fallback to your app default (seed uses "en-GB")
  return "en-gb";
}

export async function detectLanguage(
  text: string,
  projectId?: string
): Promise<{
  languageCode: string;     // e.g. "en"
  confidence: number;       // 0..1
  flutterLocale: string;    // hyphenated: "en-gb"
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

    const lang = response.languages?.[0];
    const languageCode = (lang?.languageCode || "unknown").toLowerCase();
    const confidence = lang?.confidence ?? 0;
    const flutterLocale = toHyphenLocale(languageCode); // <- now hyphenated

    if (confidence < 0.5) {
      console.warn("⚠️ detectLanguage: Low confidence", { languageCode, confidence });
    }

    // If your Flutter side prefers "en-GB" casing (titlecase region), do it here:
    const normalized = flutterLocale.replace(
      /^([a-z]{2})(?:-([a-z]{2}))?$/i,
      (_, a, b) => (b ? `${a.toLowerCase()}-${b.toUpperCase()}` : a.toLowerCase())
    ); // e.g. "en-gb" -> "en-GB"

    return { languageCode, confidence, flutterLocale: normalized };
  } catch (err) {
    console.error("❌ detectLanguage failed:", err);
    return { languageCode: "unknown", confidence: 0, flutterLocale: "en-GB" };
  }
}