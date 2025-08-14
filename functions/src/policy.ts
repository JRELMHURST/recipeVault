import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { getUserEntitlementFromRevenueCat } from "./get_user_entitlement.js";

const firestore = getFirestore();

/** 🔐 Centralised tier limits */
export const tierLimits: Record<
  "free" | "home_chef" | "master_chef",
  { translation: number; recipes: number; images: number }
> = {
  free:        { translation: 0,  recipes: 0,   images: 0 },
  home_chef:   { translation: 5,  recipes: 20,  images: 30 },
  master_chef: { translation: 20, recipes: 100, images: 250 },
};

/** 🧩 Resolve user tier: prefer Firestore, fall back to RevenueCat helper */
async function getResolvedTier(uid: string): Promise<"free" | "home_chef" | "master_chef"> {
  const userRef = firestore.collection("users").doc(uid);
  const doc = await userRef.get();
  const data = doc.data();

  const firestoreTier = data?.tier as "free" | "home_chef" | "master_chef" | undefined;
  const entitlementId = data?.entitlementId as string | undefined;

  if (firestoreTier) {
    console.log(`🎯 Using Firestore tier for ${uid}: ${firestoreTier} (entitlementId: ${entitlementId ?? "none"})`);
    return firestoreTier;
  }

  console.warn(`⚠️ Tier missing in Firestore — resolving via RevenueCat for ${uid}...`);
  const tier = await getUserEntitlementFromRevenueCat(uid); // returns a tier already

  // Persist for next time
  await userRef.set({ tier }, { merge: true });
  console.log(`✅ Firestore updated from RevenueCat → Tier: ${tier}`);

  return tier;
}

/** 🧠 GPT recipe generation enforcement */
async function enforceGptRecipePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const limits = tierLimits[tier];

  const monthKey = new Date().toISOString().slice(0, 7); // YYYY-MM
  const usageDoc = await firestore.doc(`users/${uid}/aiUsage/usage`).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;

  if (Number.isFinite(limits.recipes) && monthlyUsed >= limits.recipes) {
    throw new HttpsError(
      "resource-exhausted",
      `${tier.replace("_", " ")} plan allows up to ${limits.recipes} AI recipes per month.`
    );
  }

  console.log(`✅ GPT usage allowed → Tier: ${tier}, Used this month: ${monthlyUsed}/${limits.recipes}`);
}

/** 📈 GPT usage increment */
async function incrementGptRecipeUsage(uid: string): Promise<void> {
  const monthKey = new Date().toISOString().slice(0, 7);
  const updates: Record<string, any> = {
    total: FieldValue.increment(1),
    [monthKey]: FieldValue.increment(1),
  };

  await firestore.doc(`users/${uid}/aiUsage/usage`).set(updates, { merge: true });
  console.log(`📈 GPT usage incremented for UID ${uid}`);
}

/** 🧠 Translation limit enforcement */
async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const limits = tierLimits[tier];

  console.log(`🧪 enforceTranslationPolicy → UID: ${uid}, Tier: ${tier}`);

  // Master tier is unlimited for translation in this policy
  if (tier === "master_chef") {
    console.log("🟢 Master Chef tier — translation allowed.");
    return;
  }

  const monthKey = new Date().toISOString().slice(0, 7);
  const usageDoc = await firestore.doc(`users/${uid}/translationUsage/usage`).get();
  const monthlyUsed = usageDoc.data()?.[monthKey] || 0;

  if (Number.isFinite(limits.translation) && monthlyUsed >= limits.translation) {
    throw new HttpsError(
      "resource-exhausted",
      `${tier.replace("_", " ")} plan allows up to ${limits.translation} translations per month.`
    );
  }

  console.log(`✅ Translation allowed → Tier: ${tier}, Used this month: ${monthlyUsed}/${limits.translation}`);
}

/** 📈 Translation usage increment */
async function incrementTranslationUsage(uid: string): Promise<void> {
  const monthKey = new Date().toISOString().slice(0, 7);
  const updates: Record<string, any> = {
    total: FieldValue.increment(1),
    [monthKey]: FieldValue.increment(1),
  };

  await firestore.doc(`users/${uid}/translationUsage/usage`).set(updates, { merge: true });
  console.log(`📈 Translation usage incremented for UID ${uid}`);
}

export {
  enforceGptRecipePolicy,
  incrementGptRecipeUsage,
  enforceTranslationPolicy,
  incrementTranslationUsage,
  getResolvedTier,
};