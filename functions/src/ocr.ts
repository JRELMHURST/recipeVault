// functions/src/ocr.ts
import vision from "@google-cloud/vision";
import "./firebase.js";
import { enforceAndConsume } from "./usage_service.js"; // ✅ Quota enforcement

// 📷 Google Cloud Vision client
const visionClient = new vision.ImageAnnotatorClient();

/**
 * Run OCR (Optical Character Recognition) on an array of image URLs
 * using Google Cloud Vision API and merge the results into one string.
 *
 * @param uid - Firebase user ID (used for quota enforcement)
 * @param imageUrls - Array of image URLs or GCS URIs
 * @returns Detected text across all images (cleaned + merged)
 */
export async function extractTextFromImages(
  uid: string,
  imageUrls: string[]
): Promise<string> {
  if (!uid) {
    throw new Error("❌ OCR called without UID.");
  }
  if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
    throw new Error("❌ No image URLs provided for OCR.");
  }

  // 🚦 Enforce quota (1 credit per image)
  await enforceAndConsume(uid, "imageUsage", imageUrls.length);

  console.info({
    msg: "🔍 OCR started",
    uid,
    images: imageUrls.length,
  });

  const ocrResults = await Promise.all(
    imageUrls.map(async (url, i) => {
      try {
        const [result] = await visionClient.documentTextDetection(url);
        const text = result.fullTextAnnotation?.text ?? "";
        console.debug({
          msg: "📄 OCR partial result",
          index: i + 1,
          chars: text.length,
          preview: text.slice(0, 80).replace(/\s+/g, " "),
        });
        return text;
      } catch (err) {
        console.error({ msg: "❌ OCR failed", index: i + 1, url, err });
        return "";
      }
    })
  );

  // Merge + clean
  const mergedText = ocrResults
    .join("\n")
    .replace(/[ \t]+\n/g, "\n") // trim line endings
    .replace(/\s{2,}/g, " ") // collapse spaces
    .trim();

  console.info({
    msg: "📝 OCR complete",
    uid,
    totalChars: mergedText.length,
  });

  if (!mergedText) {
    console.warn("⚠️ OCR produced empty text");
  }

  return mergedText;
}