// text_utils.ts

/**
 * Cleans OCR or user-generated text to improve language detection and translation accuracy.
 */
export function cleanText(input: string): string {
  return input
    .replace(/[^À-ſa-zA-Z0-9\s.,:;()%-]/g, '') // keep accented chars and basic punctuation
    .replace(/\s{2,}/g, ' ') // collapse multiple spaces
    .trim();
}

/**
 * Prints a preview snippet of any long text for logging purposes.
 */
export function previewText(label: string, text: string, maxChars = 300): void {
  console.log(`📄 ${label} preview:`);
  console.log(text.slice(0, maxChars));
  if (text.length > maxChars) console.log('... (truncated)');
}