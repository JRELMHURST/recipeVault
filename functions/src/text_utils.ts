/**
 * Utility helpers for OCR and GPT text processing
 */

/**
 * Cleans OCR or user-generated text to improve language detection,
 * translation accuracy, and GPT formatting consistency.
 * - Unicode normalisation (NFKC) to unify weird forms
 * - Remove zero‑width chars + stray CRs
 * - Trim trailing spaces at line ends
 * - Collapse long runs of whitespace but keep paragraph breaks
 */
export function cleanText(input: string): string {
  return input
    .normalize("NFKC")                       // unify ligatures/fractions, etc.
    .replace(/[\u200B-\u200D\uFEFF]/g, "")   // strip zero‑width chars
    .replace(/\r/g, "")                      // CR -> nothing (use \n only)
    .replace(/[ \t]+\n/g, "\n")              // trim line ends
    .replace(/\n{3,}/g, "\n\n")              // collapse huge blank gaps to one blank line
    .replace(/[ \t]{2,}/g, " ")              // collapse long runs of spaces/tabs
    .trim();
}

/**
 * Logs a short preview of text content with an optional max length (default: 300).
 * Preserves newlines and shows lengths to help debugging.
 */
export function previewText(label: string, text: string, maxChars = 300): void {
  const preview = text.slice(0, maxChars);
  console.log(`📄 ${label} preview (${preview.length}/${text.length} chars):`);
  console.log(preview);
  if (text.length > maxChars) console.log("… (truncated)");
}