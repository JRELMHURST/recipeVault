// functions/src/ocr.ts
import vision, { protos } from "@google-cloud/vision";
import crypto from "crypto";
import "./firebase.js";
import { getStorage } from "firebase-admin/storage";
import { firestore } from "./firebase.js";
import { enforceAndConsume } from "./usage_service.js";

// Reuse a single Vision client
const visionClient = new vision.ImageAnnotatorClient();

// 📦 Cache collection + TTL
const OCR_CACHE_COLLECTION = "ocr_cache";
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

/** Convert a Firebase Storage download URL into a gs:// URI when possible. */
function toGcsUriIfSameBucket(url: string): string {
  try {
    const m = url.match(/\/o\/([^?]+)\?/);
    if (!m) return url;

    const path = decodeURIComponent(m[1]); // users/uid/tempUploads/file.jpg
    const bucketName = getStorage().bucket().name;
    if (!bucketName) return url;

    return `gs://${bucketName}/${path}`;
  } catch {
    return url;
  }
}

/** Small, safe normalisation for OCR text. */
function clean(text: string): string {
  return text
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\r/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function sha256(input: string): string {
  return crypto.createHash("sha256").update(input).digest("hex");
}

async function getCachedTextForUri(gsUri: string): Promise<string | null> {
  const key = sha256(gsUri);
  const ref = firestore.collection(OCR_CACHE_COLLECTION).doc(key);
  const snap = await ref.get();
  if (!snap.exists) return null;
  const data = snap.data() as { text?: string; expiresAt?: FirebaseFirestore.Timestamp | Date };
  if (!data?.text) return null;

  // Support Date or Timestamp shapes
  const expiresAt =
    data.expiresAt instanceof Date ? data.expiresAt : data.expiresAt?.toDate?.();
  if (!expiresAt || expiresAt.getTime() < Date.now()) return null; // expired
  return data.text;
}

async function setCachedTextForUri(gsUri: string, text: string): Promise<void> {
  if (!text.trim()) return;
  const key = sha256(gsUri);
  const ref = firestore.collection(OCR_CACHE_COLLECTION).doc(key);
  await ref.set({
    text,
    // Using JS Date is fine with Admin SDK; Firestore will store as Timestamp
    expiresAt: new Date(Date.now() + CACHE_TTL_MS),
  });
}

/**
 * Run OCR on an array of image URLs / GCS URIs using Google Cloud Vision and
 * merge the results into a single cleaned string.
 *
 * Quota: consumes 1 imageUsage credit per image.
 */
export async function extractTextFromImages(
  uid: string,
  imageUrls: string[]
): Promise<string> {
  if (!uid) throw new Error("❌ OCR called without UID.");
  if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
    throw new Error("❌ No image URLs provided for OCR.");
  }

  // 🚦 Enforce quota (1 credit per image)
  await enforceAndConsume(uid, "imageUsage", imageUrls.length);

  // Prefer gs:// for your own bucket (faster + stable key for cache)
  const uris = imageUrls.map((u) =>
    u.startsWith("gs://") ? u : toGcsUriIfSameBucket(u)
  );

  console.info({ msg: "🔍 OCR started (batched + cache)", uid, images: uris.length });

  // Language hints help accuracy/latency
  const languageHints = [
    "en",
    "en-GB",
    "es",
    "fr",
    "de",
    "it",
    "nl",
    "pl",
    "bg",
    "cs",
    "da",
    "el",
    "ga",
    "cy",
  ];

  // 1) Try cache for each URI (in parallel)
  const cachedTexts = await Promise.all(uris.map((u) => getCachedTextForUri(u)));

  // 2) Determine which indices still need OCR
  const missIndices: number[] = [];
  cachedTexts.forEach((t, i) => {
    if (!t) missIndices.push(i);
  });

  // 3) If we have misses, call Vision in one batch for *only* the misses
  let freshTextsByIndex = new Map<number, string>();
  if (missIndices.length > 0) {
    const missRequests: protos.google.cloud.vision.v1.IAnnotateImageRequest[] =
      missIndices.map((i) => ({
        image: { source: { imageUri: uris[i] } },
        features: [
          {
            // Use the enum to satisfy TS
            type:
              protos.google.cloud.vision.v1.Feature.Type
                .DOCUMENT_TEXT_DETECTION,
          },
        ],
        imageContext: { languageHints },
      }));

    try {
      const [batch] = await visionClient.batchAnnotateImages({ requests: missRequests });
      const responses =
        (batch?.responses as protos.google.cloud.vision.v1.IAnnotateImageResponse[]) ?? [];

      // Map responses back to original indices
      responses.forEach((r, idxInMisses) => {
        const originalIndex = missIndices[idxInMisses];
        const text = r.fullTextAnnotation?.text ?? "";
        if (!text && r.error) {
          console.warn("⚠️ OCR page error", {
            index: originalIndex + 1,
            code: r.error.code,
            msg: r.error.message,
          });
        }
        freshTextsByIndex.set(originalIndex, text);
      });

      // 4) Populate cache for any fresh hits
      await Promise.all(
        missIndices.map(async (i) => {
          const t = freshTextsByIndex.get(i) ?? "";
          if (t.trim()) {
            try {
              await setCachedTextForUri(uris[i], t);
            } catch (e) {
              console.warn("⚠️ Failed to cache OCR text", { uri: uris[i], err: e });
            }
          }
        })
      );
    } catch (err) {
      console.error("❌ OCR batchAnnotateImages failed", err);
      // Keep prior behavior: on failure, treat all misses as empty strings
      missIndices.forEach((i) => freshTextsByIndex.set(i, ""));
    }
  }

  // 5) Combine cached + fresh back in original order
  const parts = uris.map((_, i) => cachedTexts[i] ?? freshTextsByIndex.get(i) ?? "");
  const merged = clean(parts.join("\n"));

  console.info({
    msg: "📝 OCR complete (batched + cache)",
    uid,
    totalChars: merged.length,
    cacheHits: uris.length - (freshTextsByIndex.size || 0),
    freshCalls: freshTextsByIndex.size || 0,
  });

  if (!merged) console.warn("⚠️ OCR produced empty text");

  return merged;
}