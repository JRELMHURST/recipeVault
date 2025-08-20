// functions/src/ocr.ts
import vision from "@google-cloud/vision";
import "./firebase.js";
import { enforceAndConsume } from "./usage_service.js";  // ✅ enforce usage

const visionClient = new vision.ImageAnnotatorClient();

/**
 * Runs OCR (Optical Character Recognition) on an array of image URLs
 * using Google Cloud Vision API and merges the results into one string.
 *
 * @param uid - Firebase user ID (used for quota enforcement)
 * @param imageUrls - Array of image URLs or GCS URIs
 */
export async function extractTextFromImages(
  uid: string,
  imageUrls: string[]
): Promise<string> {
  if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
    throw new Error("❌ No image URLs provided for OCR.");
  }

  // 🚦 Quota enforcement (atomic, transactional)
  await enforceAndConsume(uid, "imageUsage", imageUrls.length);

  console.log(`🔍 Running OCR on ${imageUrls.length} image(s)...`);

  const ocrResults = await Promise.all(
    imageUrls.map(async (url, index) => {
      try {
        const [result] = await visionClient.documentTextDetection(url);
        const text = result.fullTextAnnotation?.text ?? "";
        console.log(
          `📄 OCR result from image ${index + 1}: ${text.slice(0, 100)}...`
        );
        return text;
      } catch (err) {
        console.error(`❌ OCR failed for image ${index + 1}: ${url}`, err);
        return "";
      }
    })
  );

  const mergedText = ocrResults.join("\n").trim();
  console.log("📝 Merged OCR text length:", mergedText.length);

  return mergedText;
}