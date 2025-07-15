import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const firestore = getFirestore();

/** Resolves the tier based on entitlement ID */
function resolveTierFromEntitlement(entitlementId: string): 'taster' | 'homeChef' | 'masterChef' {
  switch (entitlementId) {
    case 'master_chef_monthly':
    case 'master_chef_yearly':
      return 'masterChef';
    case 'home_chef_monthly':
      return 'homeChef';
    default:
      return 'taster';
  }
}

/** Retrieves the resolved tier for a user based on entitlement ID */
async function getResolvedTier(uid: string): Promise<'taster' | 'homeChef' | 'masterChef'> {
  const userDoc = await firestore.collection("users").doc(uid).get();
  const entitlementId = userDoc.data()?.entitlementId;
  if (!entitlementId) return 'taster';
  return resolveTierFromEntitlement(entitlementId);
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

/** Enforces GPT recipe generation limits based on subscription tier. */
async function enforceGptRecipePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);

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

  if (tier === "taster") {
    throw new HttpsError("permission-denied", "Your 7-day trial has ended. Please subscribe to continue using RecipeVault.");
  }

  if (tier === "homeChef" && monthlyUsed >= 20) {
    throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 20 recipe generations per month.");
  }
}

/** Increments GPT usage count for non-MasterChef users */
async function incrementGptRecipeUsage(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "masterChef") return;

  const updates: Record<string, any> = { total: FieldValue.increment(1) };
  const monthKey = new Date().toISOString().slice(0, 7);
  updates[monthKey] = FieldValue.increment(1);

  await firestore.collection("aiUsage").doc(uid).set(updates, { merge: true });
}

/** Enforces translation limits by subscription tier */
async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);

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

  if (tier === "taster") {
    throw new HttpsError("permission-denied", "Translation is only available during your trial or with a paid plan.");
  }

  if (tier === "homeChef" && monthlyUsed >= 5) {
    throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 5 translations per month.");
  }
}

/** Increments translation usage count for non-MasterChef users */
async function incrementTranslationUsage(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "masterChef") return;

  const updates: Record<string, any> = { total: FieldValue.increment(1) };
  const monthKey = new Date().toISOString().slice(0, 7);
  updates[monthKey] = FieldValue.increment(1);

  await firestore.collection("translationUsage").doc(uid).set(updates, { merge: true });
}

export {
  isTrialActive,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
  enforceTranslationPolicy,
  incrementTranslationUsage,
};