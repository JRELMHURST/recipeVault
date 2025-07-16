import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { getUserEntitlementFromRevenueCat } from "./get_user_entitlement.js";

const firestore = getFirestore();

/** Centralised plan limits for reference */
export const tierLimits = {
  taster:     { translation: 1, recipes: 5, images: 5 },
  home_chef:  { translation: 5, recipes: 20, images: 20 },
  master_chef:{ translation: Infinity, recipes: Infinity, images: Infinity },
};

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

/** Retrieves the resolved tier for a user via Firestore or RevenueCat fallback */
async function getResolvedTier(uid: string): Promise<'taster' | 'home_chef' | 'master_chef'> {
  const userRef = firestore.collection("users").doc(uid);
  const doc = await userRef.get();
  const userData = doc.data();

  console.log(`📄 Firestore user data for ${uid}:`, userData);

  const firestoreTier = userData?.tier;
  const firestoreEntitlement = userData?.entitlementId;

  if (firestoreTier && firestoreEntitlement) {
    console.log(`🎯 Using Firestore tier for UID ${uid}:`, {
      tier: firestoreTier,
      entitlementId: firestoreEntitlement,
    });
    return firestoreTier;
  }

  console.warn(`⚠️ Incomplete Firestore tier for UID ${uid} — resolving from RevenueCat...`);

  const entitlementFromRevenueCat = await getUserEntitlementFromRevenueCat(uid);
  if (entitlementFromRevenueCat) {
    const resolvedTier = resolveTierFromEntitlement(entitlementFromRevenueCat);

    const update: Record<string, any> = {
      tier: resolvedTier,
      entitlementId: entitlementFromRevenueCat,
    };

    if (resolvedTier !== 'taster') {
      update.trialStartDate = FieldValue.delete();
      update.trialActive = FieldValue.delete();
      console.log(`🧹 Removed trial fields for UID ${uid} due to upgrade.`);
    }

    await userRef.set(update, { merge: true });
    console.log(`✅ Updated Firestore tier for UID ${uid}:`, {
      tier: resolvedTier,
      entitlementId: entitlementFromRevenueCat,
    });
    return resolvedTier;
  }

  console.warn(`❌ No entitlement found in RevenueCat — defaulting to "taster" for UID ${uid}`);
  return firestoreTier ?? 'taster';
}

/** Checks if the user is within their 7-day Taster trial period. */
async function isTrialActive(uid: string): Promise<boolean> {
  const doc = await firestore.collection("users").doc(uid).get();
  const startStr = doc.data()?.trialStartDate;
  if (!startStr) return false;

  const start = new Date(startStr);
  const now = new Date();
  const days = (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
  const active = days < 7;

  console.log(`⏱️ Trial check for UID ${uid}: ${active ? 'ACTIVE' : 'EXPIRED'} (${days.toFixed(1)} days elapsed)`);
  return active;
}

/** Enforces GPT recipe generation limits based on subscription tier. */
async function enforceGptRecipePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const limits = tierLimits[tier];

  const monthKey = new Date().toISOString().slice(0, 7);
  const usageDoc = await firestore.doc(`users/${uid}/aiUsage/usage`).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;
  const totalUsed = usageDoc.data()?.total || 0;

  if (await isTrialActive(uid)) {
    console.log(`🧪 Trial user (${uid}) — GPT usage: total=${totalUsed}, month=${monthlyUsed}`);
    if (totalUsed >= limits.recipes) {
      throw new HttpsError("permission-denied", `Taster trial includes up to ${limits.recipes} AI recipes. Upgrade to continue.`);
    }
    return;
  }

  if (limits.recipes !== Infinity && monthlyUsed >= limits.recipes) {
    throw new HttpsError("resource-exhausted", `${tier.replace("_", " ")} plan allows up to ${limits.recipes} AI recipes per month.`);
  }

  console.log(`✅ GPT usage allowed for UID ${uid} — tier: ${tier}, monthUsed: ${monthlyUsed}`);
}

/** Increments GPT usage count for non-MasterChef users */
async function incrementGptRecipeUsage(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "master_chef") return;

  const monthKey = new Date().toISOString().slice(0, 7);
  const updates: Record<string, any> = {
    total: FieldValue.increment(1),
    [monthKey]: FieldValue.increment(1),
  };

  await firestore.doc(`users/${uid}/aiUsage/usage`).set(updates, { merge: true });
  console.log(`📈 GPT usage incremented for UID ${uid}`);
}

/** Enforces translation limits by subscription tier */
async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const limits = tierLimits[tier];

  console.log(`🧪 enforceTranslationPolicy for UID ${uid}`);
  console.log(`📊 Resolved tier: ${tier}`);

  if (tier === "master_chef") {
    console.log("🟢 Master Chef tier — translation allowed.");
    return;
  }

  const monthKey = new Date().toISOString().slice(0, 7);
  const usageDoc = await firestore.doc(`users/${uid}/translationUsage/usage`).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;
  const totalUsed = usageDoc.data()?.total || 0;

  if (await isTrialActive(uid)) {
    console.log(`🧪 Trial translation usage — UID: ${uid}, total: ${totalUsed}`);
    if (totalUsed >= limits.translation) {
      throw new HttpsError("permission-denied", `Taster trial includes ${limits.translation} translation. Upgrade to continue.`);
    }
    return;
  }

  if (limits.translation !== Infinity && monthlyUsed >= limits.translation) {
    throw new HttpsError("resource-exhausted", `${tier.replace("_", " ")} plan allows up to ${limits.translation} translations per month.`);
  }

  console.log(`✅ Translation usage allowed for UID ${uid} — tier: ${tier}, monthUsed: ${monthlyUsed}`);
}

/** Increments translation usage count for non-MasterChef users */
async function incrementTranslationUsage(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "master_chef") return;

  const monthKey = new Date().toISOString().slice(0, 7);
  const updates: Record<string, any> = {
    total: FieldValue.increment(1),
    [monthKey]: FieldValue.increment(1),
  };

  await firestore.doc(`users/${uid}/translationUsage/usage`).set(updates, { merge: true });
  console.log(`📈 Translation usage incremented for UID ${uid}`);
}

export {
  isTrialActive,
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
  enforceTranslationPolicy,
  incrementTranslationUsage,
  getResolvedTier,
};