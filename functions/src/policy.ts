import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { getUserEntitlementFromRevenueCat } from "./get_user_entitlement.js";

const firestore = getFirestore();

/** 🔐 Centralised tier limits (no 'free') */
export const tierLimits: Record<
  "home_chef" | "master_chef",
  { translation: number; recipes: number; images: number }
> = {
  home_chef:   { translation: 5,  recipes: 20,  images: 30 },
  master_chef: { translation: 20, recipes: 100, images: 250 },
};

/** Internal tier types */
type PaidTier = keyof typeof tierLimits;          // "home_chef" | "master_chef"
type TierOrNone = PaidTier | "none";

/** 🧭 Helpers */
function monthKey(): string {
  return new Date().toISOString().slice(0, 7); // YYYY-MM
}

function usagePath(
  uid: string,
  kind: "aiUsage" | "translationUsage" | "imageUsage"
) {
  return `users/${uid}/${kind}/usage`;
}

async function getMonthlyUsed(
  uid: string,
  kind: "aiUsage" | "translationUsage" | "imageUsage"
) {
  const key = monthKey();
  const snap = await firestore.doc(usagePath(uid, kind)).get();
  return snap.data()?.[key] || 0;
}

async function addMonthlyUsage(
  uid: string,
  kind: "aiUsage" | "translationUsage" | "imageUsage",
  by = 1
) {
  const key = monthKey();
  const updates: Record<string, any> = {
    total: FieldValue.increment(by),
    [key]: FieldValue.increment(by),
  };
  await firestore.doc(usagePath(uid, kind)).set(updates, { merge: true });
}

/** 🔒 Narrow to a paid tier or throw (also gives TS the right type) */
function requirePaidTier(tier: TierOrNone): PaidTier {
  if (tier === "none") {
    throw new HttpsError(
      "permission-denied",
      "A free trial or subscription is required to use this feature."
    );
  }
  return tier;
}

/** 🧩 Resolve user tier: prefer Firestore, fall back to RevenueCat helper */
export async function getResolvedTier(uid: string): Promise<TierOrNone> {
  const userRef = firestore.collection("users").doc(uid);
  const doc = await userRef.get();
  const data = doc.data();

  // Allow 'none' or paid tiers; treat anything else/unknown as 'none'
  const fsTierRaw = (data?.tier as string | undefined) ?? "none";
  const firestoreTier: TierOrNone =
    fsTierRaw === "home_chef" || fsTierRaw === "master_chef" ? fsTierRaw : "none";

  const entitlementId = data?.entitlementId as string | undefined;

  if (doc.exists) {
    console.log(
      `🎯 Using Firestore tier for ${uid}: ${firestoreTier} (entitlementId: ${
        entitlementId ?? "none"
      })`
    );
    return firestoreTier;
  }

  console.warn(
    `⚠️ Tier missing in Firestore — resolving via RevenueCat for ${uid}...`
  );
  const rcTier = await getUserEntitlementFromRevenueCat(uid); // 'home_chef' | 'master_chef' | 'none'
  await userRef.set({ tier: rcTier }, { merge: true });
  console.log(`✅ Firestore updated from RevenueCat → Tier: ${rcTier}`);

  return rcTier === "home_chef" || rcTier === "master_chef" ? rcTier : "none";
}

/** 🧠 Recipe-card (GPT formatting) limit enforcement */
export async function enforceGptRecipePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const paidTier = requirePaidTier(tier);           // ⬅️ type-narrow
  const limits = tierLimits[paidTier];              // ⬅️ safe index
  const monthlyUsed = await getMonthlyUsed(uid, "aiUsage");

  if (monthlyUsed >= limits.recipes) {
    throw new HttpsError(
      "resource-exhausted",
      `${paidTier.replace("_", " ")} plan allows up to ${limits.recipes} AI recipes per month.`
    );
  }

  console.log(
    `✅ GPT usage allowed → Tier: ${paidTier}, Used this month: ${monthlyUsed}/${limits.recipes}`
  );
}

/** 📈 Recipe-card usage increment */
export async function incrementGptRecipeUsage(uid: string): Promise<void> {
  await addMonthlyUsage(uid, "aiUsage", 1);
  console.log(`📈 GPT usage incremented for UID ${uid}`);
}

/** 🧠 Translation limit enforcement */
export async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const paidTier = requirePaidTier(tier);           // ⬅️ type-narrow
  const limits = tierLimits[paidTier];
  const monthlyUsed = await getMonthlyUsed(uid, "translationUsage");

  if (monthlyUsed >= limits.translation) {
    throw new HttpsError(
      "resource-exhausted",
      `${paidTier.replace("_", " ")} plan allows up to ${limits.translation} translations per month.`
    );
  }

  console.log(
    `✅ Translation allowed → Tier: ${paidTier}, Used this month: ${monthlyUsed}/${limits.translation}`
  );
}

/** 📈 Translation usage increment */
export async function incrementTranslationUsage(uid: string): Promise<void> {
  await addMonthlyUsage(uid, "translationUsage", 1);
  console.log(`📈 Translation usage incremented for UID ${uid}`);
}

/** 🖼️ Image upload/processing enforcement (by N images per request) */
export async function enforceImageUploadPolicy(
  uid: string,
  by: number
): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;

  const tier = await getResolvedTier(uid);
  const paidTier = requirePaidTier(tier);           // ⬅️ type-narrow
  const limits = tierLimits[paidTier];

  const monthlyUsed = await getMonthlyUsed(uid, "imageUsage");
  const wouldBe = monthlyUsed + by;

  if (wouldBe > limits.images) {
    const remaining = Math.max(0, limits.images - monthlyUsed);
    throw new HttpsError(
      "resource-exhausted",
      `${paidTier.replace("_", " ")} plan allows up to ${limits.images} image uploads per month. Remaining this month: ${remaining}.`
    );
  }

  console.log(
    `✅ Image usage allowed → Tier: ${paidTier}, Next usage: ${monthlyUsed}+${by}/${limits.images}`
  );
}

/** 📈 Image usage increment (by N images processed/uploaded) */
export async function incrementImageUploadUsage(uid: string, by: number): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;
  await addMonthlyUsage(uid, "imageUsage", by);
  console.log(`📈 Image usage +${by} incremented for UID ${uid}`);
}