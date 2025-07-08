import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const firestore = getFirestore();

/** Normalise tier string from client */
function normaliseTier(tier: string): 'taster' | 'homeChef' | 'masterChef' {
  if (tier === 'tasterTrial') return 'taster';
  return tier as 'taster' | 'homeChef' | 'masterChef';
}

/** Checks if the user is within their 7-day trial period. */
async function isTrialActive(uid: string): Promise<boolean> {
  const userDoc = await firestore.collection("users").doc(uid).get();
  const startStr = userDoc.data()?.trialStartDate;
  if (!startStr) return false;

  const start = new Date(startStr);
  const now = new Date();
  const days = (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
  return days < 7;
}

/** Enforces GPT recipe generation policy by tier. */
async function enforceGptRecipePolicy(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  const monthKey = new Date().toISOString().slice(0, 7);

  if (await isTrialActive(uid)) return;

  if (normTier === "taster") {
    const usageDoc = await firestore.collection("aiUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 3) {
      throw new HttpsError("resource-exhausted", "Taster plan allows up to 3 recipe generations per month.");
    }
  }

  if (normTier === "homeChef") {
    const usageDoc = await firestore.collection("aiUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 20) {
      throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 20 recipe generations per month.");
    }
  }
}

/** Increments monthly GPT recipe usage counter for user */
async function incrementGptRecipeUsage(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  if (normTier === "masterChef" || await isTrialActive(uid)) return;

  const monthKey = new Date().toISOString().slice(0, 7);
  await firestore.collection("aiUsage").doc(uid).set(
    { [monthKey]: FieldValue.increment(1) },
    { merge: true }
  );
}

/** Enforces translation usage policy based on subscription tier. */
async function enforceTranslationPolicy(uid: string, tier: string): Promise<void> {
  const normTier = normaliseTier(tier);
  const monthKey = new Date().toISOString().slice(0, 7);

  if (await isTrialActive(uid)) return;

  if (normTier === "taster") {
    throw new HttpsError("permission-denied", "Translation is not available on the Taster plan.");
  }

  if (normTier === "homeChef") {
    const usageDoc = await firestore.collection("translationUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 5) {
      throw new HttpsError("resource-exhausted", "Home Chef users can translate up to 5 recipes per month.");
    }
  }
}

/** Increments monthly translation usage counter. */
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