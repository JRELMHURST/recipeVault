// functions/src/usage_service.ts
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const firestore = getFirestore();

/** Types of usage we track */
export type UsageKind = "aiUsage" | "translationUsage" | "imageUsage";

/** Internal subscription tiers */
export type Tier = "home_chef" | "master_chef" | "none";

/** Centralised tier limits (no 'free') */
export const tierLimits: Record<
  Exclude<Tier, "none">,
  { translation: number; recipes: number; images: number }
> = {
  home_chef:   { translation: 5,  recipes: 20,  images: 30 },
  master_chef: { translation: 20, recipes: 100, images: 250 },
};

/** 📅 Current month key, e.g. "2025-08" */
export function monthKey(): string {
  return new Date().toISOString().slice(0, 7);
}

/** 🔗 Firestore path for a given usage kind */
export function usagePath(uid: string, kind: UsageKind): string {
  return `users/${uid}/${kind}/usage`;
}

/** 📊 Get the monthly usage count for a given user/kind */
export async function getMonthlyUsage(
  uid: string,
  kind: UsageKind
): Promise<number> {
  const key = monthKey();
  const snap = await firestore.doc(usagePath(uid, kind)).get();
  return snap.exists ? snap.data()?.[key] || 0 : 0;
}

/** 📈 Increment usage for this month (and total lifetime) */
export async function incrementMonthlyUsage(
  uid: string,
  kind: UsageKind,
  by = 1
): Promise<void> {
  const key = monthKey();
  const updates: Record<string, any> = {
    total: FieldValue.increment(by),
    [key]: FieldValue.increment(by),
  };
  await firestore.doc(usagePath(uid, kind)).set(updates, { merge: true });
}

/** 🧹 Reset usage for a given month (if ever needed manually) */
export async function resetMonthlyUsage(
  uid: string,
  kind: UsageKind
): Promise<void> {
  const key = monthKey();
  await firestore.doc(usagePath(uid, kind)).set(
    { [key]: 0 },
    { merge: true }
  );
}

/* ────────────────────────────────────────────────
   🚦 Policy Enforcement Wrappers
   ──────────────────────────────────────────────── */

/** Get resolved tier string from Firestore */
export async function getResolvedTier(uid: string): Promise<Tier> {
  const snap = await firestore.collection("users").doc(uid).get();
  const tier = snap.data()?.tier as Tier | undefined;
  return tier ?? "none";
}

/** Translation policy enforcement */
export async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "none") throw new HttpsError("permission-denied", "Subscription required.");

  const used = await getMonthlyUsage(uid, "translationUsage");
  if (used >= tierLimits[tier].translation) {
    throw new HttpsError("resource-exhausted", "Monthly translation limit reached.");
  }
}

/** GPT recipe policy enforcement */
export async function enforceGptRecipePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "none") throw new HttpsError("permission-denied", "Subscription required.");

  const used = await getMonthlyUsage(uid, "aiUsage");
  if (used >= tierLimits[tier].recipes) {
    throw new HttpsError("resource-exhausted", "Monthly recipe limit reached.");
  }
}

/** Image usage policy enforcement */
export async function enforceImagePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "none") throw new HttpsError("permission-denied", "Subscription required.");

  const used = await getMonthlyUsage(uid, "imageUsage");
  if (used >= tierLimits[tier].images) {
    throw new HttpsError("resource-exhausted", "Monthly image limit reached.");
  }
}