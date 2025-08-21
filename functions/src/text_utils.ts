/**
 * Utility helpers for OCR and GPT text processing
 */

/**
 * Cleans OCR or user-generated text to improve language detection,
 * translation accuracy, and GPT formatting consistency.
 */
export function cleanText(input: string): string {
  return input
    .replace(/[^À-ſa-zA-Z0-9\s.,:;()%-]/g, "") // Allow accented characters, alphanumerics, basic punctuation
    .replace(/\s{2,}/g, " ") // Collapse multiple spaces
    .trim(); // Remove leading/trailing whitespace
}

/**
 * Logs a short preview of text content with an optional max length (default: 300).
 * Useful for debugging OCR or GPT input/output.
 */
export function previewText(label: string, text: string, maxChars = 300): void {
  console.log(`📄 ${label} preview:`);
  console.log(text.slice(0, maxChars));
  if (text.length > maxChars) {
    console.log("... (truncated)");
  }
}