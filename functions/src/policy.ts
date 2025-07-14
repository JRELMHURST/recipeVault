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
 * Trial users have unlimited access during trial. After that:
 * - Taster: blocked
 * - Home Chef: 20/month
 * - Master Chef: unlimited
 */
async function enforceGptRecipePolicy(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);

  if (await isTrialActive(uid)) return;

  const monthKey = new Date().toISOString().slice(0, 7);

  if (normTier === "taster") {
    throw new HttpsError("permission-denied", "Your 7-day trial has ended. Please subscribe to continue using RecipeVault.");
  }

  if (normTier === "homeChef") {
    const usageDoc = await firestore.collection("aiUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 20) {
      throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 20 recipe generations per month.");
    }
  }
}

/** Increments monthly GPT recipe usage counter */
async function incrementGptRecipeUsage(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  if (normTier === "masterChef" || await isTrialActive(uid)) return;

  const monthKey = new Date().toISOString().slice(0, 7);
  await firestore.collection("aiUsage").doc(uid).set(
    { [monthKey]: FieldValue.increment(1) },
    { merge: true }
  );
}

/**
 * Enforces translation usage policy by subscription tier.
 * Trial users have unlimited access. After that:
 * - Taster: blocked
 * - Home Chef: 5/month
 * - Master Chef: unlimited
 */
async function enforceTranslationPolicy(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);

  if (await isTrialActive(uid)) return;

  const monthKey = new Date().toISOString().slice(0, 7);

  if (normTier === "taster") {
    throw new HttpsError("permission-denied", "Translation is only available during your trial or with a paid plan.");
  }

  if (normTier === "homeChef") {
    const usageDoc = await firestore.collection("translationUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 5) {
      throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 5 translations per month.");
    }
  }
}

/** Increments monthly translation usage counter */
async function incrementTranslationUsage(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  if (normTier !== "homeChef" || await isTrialActive(uid)) return;

  const monthKey = new Date().toISOString().slice(0, 7);
  await firestore.collection("translationUsage").doc(uid).set(
    { [monthKey]: FieldValue.increment(1) },
    { merge: true }
  );
}

export {
  isTrialActive,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
  enforceTranslationPolicy,
  incrementTranslationUsage
};