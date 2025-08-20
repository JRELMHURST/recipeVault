// functions/src/translate.ts
import { TranslationServiceClient } from "@google-cloud/translate";
import "./firebase.js";

const client = new TranslationServiceClient();

/** Keep Unicode letters + useful punctuation; normalise + collapse whitespace */
function cleanText(input: string): string {
  return input
    .normalize("NFKC")                    // unify weird forms, fractions, etc.
    .replace(/[\u200B-\u200D\uFEFF]/g, "")// strip zero-width chars
    .replace(/\r/g, "")                   // CR -> nothing
    .replace(/[ \t]+\n/g, "\n")           // trim line ends
    .replace(/\s{2,}/g, " ")              // collapse runs of spaces
    .trim();
}

/** Split into ~4500-char chunks at paragraph boundaries to stay under limits */
function chunkText(input: string, max = 4500): string[] {
  if (input.length <= max) return [input];
  const paras = input.split(/\n{2,}/); // split on blank lines
  const chunks: string[] = [];
  let buf = "";
  for (const p of paras) {
    const candidate = buf ? `${buf}\n\n${p}` : p;
    if (candidate.length > max) {
      if (buf) chunks.push(buf);
      if (p.length > max) {
        // hard-split very long paragraph
        for (let i = 0; i < p.length; i += max) {
          chunks.push(p.slice(i, i + max));
        }
        buf = "";
      } else {
        buf = p;
      }
    } else {
      buf = candidate;
    }
  }
  if (buf) chunks.push(buf);
  return chunks;
}

/** Normalise language tags (accepts 'en_GB' or 'en-GB' → 'en-GB') */
function normaliseLangTag(tag: string): string {
  const t = tag.replace("_", "-").trim();
  // Keep as provided otherwise; Cloud Translate accepts BCP‑47 (case-insensitive)
  return t;
}

/**
 * Translate text from `sourceLanguage` to `targetLanguage` (e.g. "en-GB", "pl", "de").
 * NOTE: No quota enforcement here — billing happens once at the GPT step.
 */
export async function translateText(
  text: string,
  sourceLanguage: string,
  targetLanguage: string, // e.g. "en-GB", "pl", "de"
  projectId: string
): Promise<string> {
  if (!text?.trim()) throw new Error("❌ No text provided for translation.");

  const cleanedText = cleanText(text);
  const chunks = chunkText(cleanedText);

  const src = normaliseLangTag(sourceLanguage);
  const tgt = normaliseLangTag(targetLanguage);

  console.log(`🔤 Translating ${chunks.length} chunk(s) "${src}" → "${tgt}"`);
  console.log(`📏 Original: ${text.length}, Cleaned: ${cleanedText.length}`);
  console.log(`🧪 Preview:\n${cleanedText.slice(0, 300)}\n`);

  try {
    const parent = `projects/${projectId}/locations/global`;
    const translatedPieces: string[] = [];

    for (const [i, piece] of chunks.entries()) {
      const [resp] = await client.translateText({
        parent,
        contents: [piece],
        mimeType: "text/plain",
        sourceLanguageCode: src,
        targetLanguageCode: tgt,
      });

      const translated = resp.translations?.[0]?.translatedText ?? piece;
      translatedPieces.push(translated);
      console.log(`✅ Chunk ${i + 1}/${chunks.length} translated (${piece.length} chars)`);
    }

    const out = translatedPieces.join("\n\n").trim();
    if (out === cleanedText) {
      console.warn("⚠️ Translation output equals input; translation may have been skipped.");
    }
    return out;
  } catch (err) {
    console.error("❌ Translation API failed:", err);
    // Fallback: return cleaned source so downstream still has something to format
    return cleanedText;
  }
}