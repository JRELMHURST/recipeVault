import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getStorage } from "firebase-admin/storage";
import { decode } from "html-entities";
import admin from "./firebase.js"; // ✅ Ensures Firebase is initialised
import dayjs from "dayjs";

import { extractTextFromImages } from "./ocr.js";
import { detectLanguage } from "./detect.js";
import { translateToEnglish } from "./translate.js";
import { generateFormattedRecipe } from "./gpt_logic.js";
import { cleanText, previewText } from "./text_utils.js";
import {
  getResolvedTier,
  enforceTranslationPolicy,
  incrementTranslationUsage,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
} from "./policy.js";

const REVENUECAT_SECRET_KEY = defineSecret("REVENUECAT_SECRET_KEY");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

async function deleteUploadedImage(url: string) {
  try {
    const match = url.match(/\/o\/([^?]+)\?/);
    if (!match?.[1]) {
      console.warn("❌ Could not extract path from URL:", url);
      return;
    }

    const path = decodeURIComponent(match[1]);
    const file = getStorage().bucket().file(path);
    const [exists] = await file.exists();

    if (!exists) {
      console.warn(`⚠️ Skipped deletion – file not found: ${path}`);
      return;
    }

    await file.delete();
    console.log(`🗑️ Deleted uploaded image: ${path}`);
  } catch (err) {
    console.warn(`⚠️ Error deleting image (${url}):`, err);
  }
}

export const extractAndFormatRecipe = onCall(
  {
    secrets: [REVENUECAT_SECRET_KEY, OPENAI_API_KEY],
  },
  async (request: CallableRequest<{ imageUrls: string[] }>) => {
    const start = Date.now();
    const imageUrls = request.data?.imageUrls;

    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.FUNCTIONS_PROJECT_ID ||
      "";

    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new HttpsError("invalid-argument", "Missing or invalid 'imageUrls' array");
    }

    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const tier = await getResolvedTier(uid);
    console.log(`🎟️ Subscription tier resolved as: ${tier}`);

    try {
      console.log(`📸 Starting processing of ${imageUrls.length} image(s)...`);

      const ocrText = await extractTextFromImages(imageUrls);
      if (!ocrText.trim()) {
        throw new HttpsError("invalid-argument", "No text detected in provided images.");
      }

      const cleanInput = cleanText(ocrText);
      previewText("🔎 Raw OCR text", ocrText);

      let detectedLanguage = "unknown";
      let confidence = 0;

      try {
        const detection = await detectLanguage(cleanInput, projectId);
        detectedLanguage = detection.languageCode;
        confidence = detection.confidence;
        console.log(`🌐 Detected language: ${detectedLanguage} (confidence: ${confidence})`);
      } catch (err) {
        console.warn("⚠️ Language detection failed:", err);
      }

      let translatedText = cleanInput;
      let translationUsed = false;

      const isLikelyEnglish =
        detectedLanguage.toLowerCase() === "en" ||
        detectedLanguage.toLowerCase().startsWith("en-");

if (!isLikelyEnglish) {
  try {
    console.log(`🚧 Translating from "${detectedLanguage}" → en-GB...`);
    const result = await translateToEnglish(cleanInput, detectedLanguage, projectId);

    if (result?.trim()) {
      const cleanedTranslated = cleanText(result.trim());

      // Use the translated result regardless of similarity
      translatedText = result.trim();
      translationUsed = true;
      previewText("📝 Translated preview", translatedText);

      // Only count towards usage if translation was meaningful
      const cleanedOriginal = cleanText(cleanInput);
      if (cleanedOriginal !== cleanedTranslated) {
        await enforceTranslationPolicy(uid);
        await incrementTranslationUsage(uid);
      } else {
        console.log("⚠️ Translation was minimal — skipping usage enforcement.");
      }

    } else {
      console.warn("⚠️ Translation returned empty or null. Skipping.");
    }
  } catch (err) {
    console.error("❌ Translation failed:", err);
  }
} else {
  console.log("🟢 Skipping translation – already English");
}

      const usedText = translationUsed ? translatedText : cleanInput;

      const finalText = decode(usedText.trim())
        .replace(/(?:\r\n|\r|\n){2,}/g, "\n\n")
        .trim();

      previewText("🧠 GPT input preview", finalText);

      await enforceGptRecipePolicy(uid);

      const formattedRecipe = await generateFormattedRecipe(
        finalText,
        translationUsed ? detectedLanguage : "en"
      );

      console.log("✅ GPT formatting complete.");

      await incrementGptRecipeUsage(uid);

      try {
const monthKey = dayjs().format("YYYY-MM");

// ✅ Increment AI recipe usage
await admin.firestore().doc(`users/${uid}/aiUsage/usage`).set(
  {
    [monthKey]: admin.firestore.FieldValue.increment(1),
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);

// ✅ Increment translation usage if applicable
if (translationUsed) {
  await admin.firestore().doc(`users/${uid}/translationUsage/usage`).set(
    {
      [monthKey]: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}
  console.log("📈 Synced usage metrics to Firestore");
} catch (err) {
  console.warn("⚠️ Failed to sync usage metrics to Firestore:", err);
}

      await Promise.all(imageUrls.map(deleteUploadedImage));

      // 🔄 Auto-refresh global recipes for the user
      try {
        const globalSnapshot = await admin.firestore().collection('global_recipes').get();
        if (!globalSnapshot.empty) {
          const userRecipesRef = admin.firestore().collection(`users/${uid}/recipes`);
          const batch = admin.firestore().batch();

          for (const doc of globalSnapshot.docs) {
            const globalRecipe = doc.data();
            const recipeId = doc.id;

            const docRef = userRecipesRef.doc(recipeId);
            batch.set(docRef, {
              ...globalRecipe,
              userId: uid,
              isGlobal: true,
              createdAt: globalRecipe.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          const userDocRef = admin.firestore().doc(`users/${uid}`);
          batch.update(userDocRef, {
            lastGlobalSync: admin.firestore.FieldValue.serverTimestamp(),
          });

          await batch.commit();
          console.log(`🔄 Global recipes refreshed for ${uid} (${globalSnapshot.size})`);
        }
      } catch (e) {
        console.warn(`⚠️ Failed to auto-refresh global recipes:`, e);
      }

      console.log(`🏁 Processing complete in ${Date.now() - start}ms`);

      return {
        formattedRecipe,
        originalText: ocrText,
        detectedLanguage,
        translationUsed,
        targetLanguage: "en-GB",
        imageUrls,
        isTranslated: translationUsed,
        translatedFromLanguage: translationUsed ? detectedLanguage : null,
      };
    } catch (err: any) {
      console.error("❌ extractAndFormatRecipe failed:");
      console.error("📛 Error message:", err?.message || err);
      console.error("🧵 Stack trace:\n", err?.stack || "No stack trace");
      console.error("📥 Request data:", JSON.stringify(request.data, null, 2));

      if (err instanceof HttpsError) {
        throw err;
      }

      console.error("🔥 Recipe processing failed", err);
      throw new HttpsError("internal", `❌ Failed to process recipe: ${err?.message || "Unknown error"}`);
    }
  }
);