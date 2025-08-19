// functions/src/policy.ts
import { HttpsError } from "firebase-functions/v2/https";
import {
  getMonthlyUsage,
  incrementMonthlyUsage,
} from "./usage_service.js";
import { getFirestore } from "firebase-admin/firestore";

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
type PaidTier = keyof typeof tierLimits; // "home_chef" | "master_chef"
type TierOrNone = PaidTier | "none";

/** 🔒 Narrow to a paid tier or throw */
function requirePaidTier(tier: TierOrNone): PaidTier {
  if (tier === "none") {
    throw new HttpsError(
      "permission-denied",
      "A free trial or subscription is required to use this feature."
    );
  }
  return tier;
}

/** 🧩 Resolve user tier directly from Firestore */
export async function getResolvedTier(uid: string): Promise<TierOrNone> {
  const userRef = firestore.collection("users").doc(uid);
  const doc = await userRef.get();
  const data = doc.data();

  const fsTierRaw = (data?.tier as string | undefined) ?? "none";
  const firestoreTier: TierOrNone =
    fsTierRaw === "home_chef" || fsTierRaw === "master_chef"
      ? fsTierRaw
      : "none";

  console.log(
    `🎯 Using Firestore tier for ${uid}: ${firestoreTier} (productId: ${
      data?.productId ?? "none"
    })`
  );

  return firestoreTier;
}

/* ─────────────── Enforcement & Increment Helpers ─────────────── */

/** 🧠 Recipe-card (GPT formatting) limit enforcement */
export async function enforceGptRecipePolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const paidTier = requirePaidTier(tier);
  const limits = tierLimits[paidTier];
  const monthlyUsed = await getMonthlyUsage(uid, "aiUsage");

  if (monthlyUsed >= limits.recipes) {
    throw new HttpsError(
      "resource-exhausted",
      `${paidTier.replace("_", " ")} plan allows up to ${limits.recipes} AI recipes per month.`
    );
  }
}

/** 📈 Recipe-card usage increment */
export async function incrementGptRecipeUsage(uid: string): Promise<void> {
  await incrementMonthlyUsage(uid, "aiUsage", 1);
}

/** 🧠 Translation limit enforcement */
export async function enforceTranslationPolicy(uid: string): Promise<void> {
  const tier = await getResolvedTier(uid);
  const paidTier = requirePaidTier(tier);
  const limits = tierLimits[paidTier];
  const monthlyUsed = await getMonthlyUsage(uid, "translationUsage");

  if (monthlyUsed >= limits.translation) {
    throw new HttpsError(
      "resource-exhausted",
      `${paidTier.replace("_", " ")} plan allows up to ${limits.translation} translations per month.`
    );
  }
}

/** 📈 Translation usage increment */
export async function incrementTranslationUsage(uid: string): Promise<void> {
  await incrementMonthlyUsage(uid, "translationUsage", 1);
}

/** 🖼️ Image upload/processing enforcement */
export async function enforceImageUploadPolicy(
  uid: string,
  by: number
): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;

  const tier = await getResolvedTier(uid);
  const paidTier = requirePaidTier(tier);
  const limits = tierLimits[paidTier];

  const monthlyUsed = await getMonthlyUsage(uid, "imageUsage");
  const wouldBe = monthlyUsed + by;

  if (wouldBe > limits.images) {
    const remaining = Math.max(0, limits.images - monthlyUsed);
    throw new HttpsError(
      "resource-exhausted",
      `${paidTier.replace("_", " ")} plan allows up to ${limits.images} image uploads per month. Remaining this month: ${remaining}.`
    );
  }
}

/** 📈 Image usage increment */
export async function incrementImageUploadUsage(
  uid: string,
  by: number
): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;
  await incrementMonthlyUsage(uid, "imageUsage", by);
}