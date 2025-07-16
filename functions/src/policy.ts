import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { getUserEntitlementFromRevenueCat } from "./get_user_entitlement.js";

const firestore = getFirestore();

/** Maps RevenueCat product IDs to internal tier labels */
function resolveTierFromEntitlement(entitlementId: string): 'master_chef' | 'home_chef' | 'taster' {
  switch (entitlementId) {
    case 'master_chef_yearly':
    case 'master_chef_monthly':
      return 'master_chef';
    case 'home_chef_monthly':
      return 'home_chef';
    case 'taster_trial':
    default:
      return 'taster';
  }
}

/** Retrieves the resolved tier for a user via RevenueCat */
async function getResolvedTier(uid: string): Promise<'taster' | 'home_chef' | 'master_chef'> {
  const entitlementId = await getUserEntitlementFromRevenueCat(uid);
  const tier = resolveTierFromEntitlement(entitlementId ?? 'taster');

  // Optional: update Firestore cache
  await firestore.collection("users").doc(uid).set({ entitlementId }, { merge: true });
  return tier;
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
  const usageDoc = await firestore.doc(`users/${uid}/aiUsage/usage`).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;
  const totalUsed = usageDoc.data()?.total || 0;

  if (await isTrialActive(uid)) {
    if (totalUsed >= 5) {
      throw new HttpsError("permission-denied", "Taster trial includes up to 5 AI recipes. Upgrade to continue.");
    }
    return;
  }

  if (tier === "taster") {
    throw new HttpsError("permission-denied", "Taster plan includes 5 AI recipes during the trial only. Upgrade to continue.");
  }

  if (tier === "home_chef" && monthlyUsed >= 20) {
    throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 20 AI recipes per month.");
  }
}

/** Increments GPT usage count for non-MasterChef users */
async function incrementGptRecipeUsage(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "master_chef") return;

  const updates: Record<string, any> = { total: FieldValue.increment(1) };
  const monthKey = new Date().toISOString().slice(0, 7);
  updates[monthKey] = FieldValue.increment(1);

  await firestore.doc(`users/${uid}/aiUsage/usage`).set(updates, { merge: true });
}

/** Enforces translation limits by subscription tier */
async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);

  if (tier === "master_chef") {
    console.log("🟢 Master Chef tier detected — skipping translation limit check.");
    return;
  } else {
    console.log(`🔐 Tier enforcement active — current tier: ${tier}`);
  }

  const monthKey = new Date().toISOString().slice(0, 7);
  const usageDoc = await firestore.doc(`users/${uid}/translationUsage/usage`).get();
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

  if (tier === "home_chef" && monthlyUsed >= 5) {
    throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 5 translations per month.");
  }
}

/** Increments translation usage count for non-MasterChef users */
async function incrementTranslationUsage(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "master_chef") return;

  const updates: Record<string, any> = { total: FieldValue.increment(1) };
  const monthKey = new Date().toISOString().slice(0, 7);
  updates[monthKey] = FieldValue.increment(1);

  await firestore.doc(`users/${uid}/translationUsage/usage`).set(updates, { merge: true });
}

export {
  isTrialActive,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
  enforceTranslationPolicy,
  incrementTranslationUsage,
  getResolvedTier,
};