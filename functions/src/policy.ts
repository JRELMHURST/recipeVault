import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const firestore = getFirestore();

/** Normalise tier string from client */
function normaliseTier(tier: string): 'taster' | 'homeChef' | 'masterChef' {
  return tier as 'taster' | 'homeChef' | 'masterChef';
}

/** Checks if the user is within their 7-day Taster trial period. */
async function isTrialActive(uid: string): Promise<boolean> {
  const userDoc = await firestore.collection("users").doc(uid).get();
  const startStr = userDoc.data()?.trialStartDate;
  if (!startStr) return false;

  const start = new Date(startStr);
  const now = new Date();
  const days = (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
  return days < 7;
}

/**
 * Enforces GPT recipe generation policy by subscription tier.
 * Trial users get 5 total recipe generations. After that:
 * - Taster: blocked
 * - Home Chef: 20/month
 * - Master Chef: unlimited
 */
async function enforceGptRecipePolicy(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);

  const monthKey = new Date().toISOString().slice(0, 7);
  const usageDoc = await firestore.collection("aiUsage").doc(uid).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;
  const totalUsed = usageDoc.data()?.total || 0;

  if (await isTrialActive(uid)) {
    if (totalUsed >= 5) {
      throw new HttpsError("permission-denied", "Taster trial includes up to 5 AI recipes. Upgrade to continue.");
    }
    return;
  }

  if (normTier === "taster") {
    throw new HttpsError("permission-denied", "Your 7-day trial has ended. Please subscribe to continue using RecipeVault.");
  }

  if (normTier === "homeChef" && monthlyUsed >= 20) {
    throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 20 recipe generations per month.");
  }
}

/** Increments monthly and total GPT recipe usage counter */
async function incrementGptRecipeUsage(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  if (normTier === "masterChef") return;

  const updates: Record<string, any> = {
    total: FieldValue.increment(1),
  };

  const monthKey = new Date().toISOString().slice(0, 7);
  updates[monthKey] = FieldValue.increment(1);

  await firestore.collection("aiUsage").doc(uid).set(updates, { merge: true });
}

/**
 * Enforces translation usage policy by subscription tier.
 * Trial users get 1 total translation. After that:
 * - Taster: blocked
 * - Home Chef: 5/month
 * - Master Chef: unlimited
 */
async function enforceTranslationPolicy(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);

  const monthKey = new Date().toISOString().slice(0, 7);
  const usageDoc = await firestore.collection("translationUsage").doc(uid).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;
  const totalUsed = usageDoc.data()?.total || 0;

  if (await isTrialActive(uid)) {
    if (totalUsed >= 1) {
      throw new HttpsError("permission-denied", "Taster trial includes 1 translation. Upgrade to continue.");
    }
    return;
  }

  if (normTier === "taster") {
    throw new HttpsError("permission-denied", "Translation is only available during your trial or with a paid plan.");
  }

  if (normTier === "homeChef" && monthlyUsed >= 5) {
    throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 5 translations per month.");
  }
}

/** Increments monthly and total translation usage counter */
async function incrementTranslationUsage(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  if (normTier === "masterChef") return;

  const updates: Record<string, any> = {
    total: FieldValue.increment(1),
  };

  const monthKey = new Date().toISOString().slice(0, 7);
  updates[monthKey] = FieldValue.increment(1);

  await firestore.collection("translationUsage").doc(uid).set(updates, { merge: true });
}

export {
  isTrialActive,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
  enforceTranslationPolicy,
  incrementTranslationUsage
};