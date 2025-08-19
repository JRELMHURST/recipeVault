import "./firebase.js";
import { TranslationServiceClient } from "@google-cloud/translate";
import {
  enforceTranslationPolicy,
  incrementMonthlyUsage,
} from "./usage_service.js";

const client = new TranslationServiceClient();

/** Unicode-friendly cleanup: keep diacritics, normalize, collapse whitespace */
function cleanText(input: string): string {
  return input
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\r/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function truncate(input: string, max = 5000): string {
  return input.length > max ? input.slice(0, max) : input;
}

/** Map GCP language codes to Flutter-supported locales */
function mapToFlutterLocale(code: string): string {
  const base = code.toLowerCase();

  const exact = new Set([
    "en", "en-gb", "bg", "cs", "da", "de", "el",
    "es", "fr", "ga", "it", "nl", "pl", "cy",
  ]);

  if (exact.has(base) || /^[a-z]{2}-[a-z]{2}$/i.test(base)) {
    return base.replace("-", "_");
  }

  return "en_GB";
}

export async function detectLanguage(
  uid: string,      // 🔑 must pass UID for quotas
  text: string,
  projectId?: string
): Promise<{
  languageCode: string;
  confidence: number;
  flutterLocale: string;
}> {
  if (!text?.trim()) {
    throw new Error("❌ No text provided for language detection.");
  }
  if (!uid) {
    throw new Error("❌ Missing UID for usage enforcement.");
  }

  const pid =
    projectId ||
    process.env.GCLOUD_PROJECT ||
    process.env.FUNCTIONS_PROJECT_ID ||
    process.env.GCP_PROJECT ||
    "";

  if (!pid) throw new Error("❌ No projectId available for Translate API.");

  const cleaned = truncate(cleanText(text));

  console.log(
    `🔍 Detecting language: original=${text.length} chars, cleaned=${cleaned.length} chars`
  );

  // 1. Enforce quota
  await enforceTranslationPolicy(uid);

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
      console.warn("⚠️ Low confidence in language detection.");
    }

    // 2. Increment usage
    await incrementMonthlyUsage(uid, "translationUsage");

    return { languageCode, confidence, flutterLocale };
  } catch (err) {
    console.error("❌ Language detection failed:", err);
    return { languageCode: "unknown", confidence: 0, flutterLocale: "en_GB" };
  }
}