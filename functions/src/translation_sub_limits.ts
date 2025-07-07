import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const firestore = getFirestore();

/**
 * Checks whether the user's trial is active (within 7 days of trialStartDate).
 */
async function isTrialActive(uid: string): Promise<boolean> {
  const userDoc = await firestore.collection("users").doc(uid).get();
  const startStr = userDoc.data()?.trialStartDate;
  if (!startStr) return false;

  const start = new Date(startStr);
  const now = new Date();
  const diffInDays = (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
  return diffInDays < 7;
}

/**
 * Enforces tier-based translation access.
 * Throws an error if user is not allowed to translate.
 */
export async function enforceTranslationPolicy(uid: string, tier: string): Promise<void> {
  const monthKey = new Date().toISOString().slice(0, 7); // e.g. "2025-07"

  // ✅ Trial users get full access
  if (await isTrialActive(uid)) {
    console.log("🟢 Translation allowed: user is in trial period.");
    return;
  }

  if (tier === "taster") {
    throw new HttpsError("permission-denied", "Translation is not available on the Taster plan.");
  }

  if (tier === "homeChef") {
    const usageDoc = await firestore.collection("translationUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 5) {
      throw new HttpsError("resource-exhausted", "Home Chef users can translate up to 5 recipes per month.");
    }
  }

  // ✅ MasterChef: no restriction
}

/**
 * Increments monthly translation usage for Home Chef tier (non-trial).
 */
export async function incrementTranslationUsage(uid: string, tier: string): Promise<void> {
  // Skip counting if still on trial
  if (await isTrialActive(uid)) return;
  if (tier !== "homeChef") return;

  const monthKey = new Date().toISOString().slice(0, 7);
  await firestore.collection("translationUsage").doc(uid)
    .set({ [monthKey]: FieldValue.increment(1) }, { merge: true });
}