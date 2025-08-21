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
 * @returns Detected text across all images
 */
export async function extractTextFromImages(
  uid: string,
  imageUrls: string[]
): Promise<string> {
  if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
    throw new Error("❌ No image URLs provided for OCR.");
  }

  // 🚦 Atomically enforce quota (1 credit per image)
  await enforceAndConsume(uid, "imageUsage", imageUrls.length);

  console.log(`🔍 OCR started on ${imageUrls.length} image(s)...`);

  const ocrResults = await Promise.all(
    imageUrls.map(async (url, i) => {
      try {
        const [result] = await visionClient.documentTextDetection(url);
        const text = result.fullTextAnnotation?.text ?? "";
        console.log(`📄 OCR result [${i + 1}]: ${text.slice(0, 100)}...`);
        return text;
      } catch (err) {
        console.error(`❌ OCR failed [${i + 1}] for: ${url}`, err);
        return "";
      }
    })
  );

  const mergedText = ocrResults.join("\n").trim();
  console.log(`📝 OCR complete. Merged length: ${mergedText.length}`);

  return mergedText;
}