// functions/src/usage_service.ts
import { firestore, FieldValue } from "./firebase.js";
import { HttpsError } from "firebase-functions/v2/https";

/** Types of usage we track (collection names match these keys) */
export type UsageKind = "recipeUsage" | "translatedRecipeUsage" | "imageUsage";

/** Internal subscription tiers */
export type Tier = "home_chef" | "master_chef" | "none";

/** Centralised tier limits (no 'free/none') */
export const tierLimits: Record<
  Exclude<Tier, "none">,
  {
    translatedRecipeCards: number; // clearer label for UI
    recipes: number;
    images: number;
  }
> = {
  home_chef:   { translatedRecipeCards: 5,  recipes: 20,  images: 30 },
  master_chef: { translatedRecipeCards: 20, recipes: 100, images: 250 },
};

/** Map UsageKind -> tierLimits key */
type LimitKey = "translatedRecipeCards" | "recipes" | "images";
const limitKeyByKind: Record<UsageKind, LimitKey> = {
  translatedRecipeUsage: "translatedRecipeCards",
  recipeUsage: "recipes",
  imageUsage: "images",
};

/** Map UsageKind -> error code (single source of truth) */
const errorCodeByKind: Record<UsageKind, string> = {
  recipeUsage: "RECIPE_LIMIT",
  translatedRecipeUsage: "TRANSLATED_RECIPE_LIMIT",
  imageUsage: "IMAGE_LIMIT",
};

/** 📅 Current month key in Europe/London, e.g. "2025-08" */
export function monthKey(tz: string = "Europe/London"): string {
  const now = new Date();
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
  }).formatToParts(now);
  const year = parts.find((p) => p.type === "year")?.value ?? "0000";
  const month = parts.find((p) => p.type === "month")?.value ?? "01";
  return `${year}-${month}`;
}

/** 🔗 Firestore path for a given usage kind */
export function usagePath(uid: string, kind: UsageKind): string {
  if (!uid) throw new HttpsError("invalid-argument", "uid is required");
  return `users/${uid}/${kind}/usage`;
}

/** 📊 Get the monthly usage count for a given user/kind (0 if none) */
export async function getMonthlyUsage(uid: string, kind: UsageKind): Promise<number> {
  const key = monthKey();
  const snap = await firestore.doc(usagePath(uid, kind)).get();
  return snap.exists ? Number(snap.data()?.[key] ?? 0) : 0;
}

/** 🎯 Get the monthly limit for a user/kind based on their tier */
export function getMonthlyLimit(tier: Tier, kind: UsageKind): number {
  if (tier === "none") return 0;
  const limits = tierLimits[tier];
  const k: LimitKey = limitKeyByKind[kind];
  return limits[k];
}

/** 🧮 Remaining this month (never negative) */
export async function getMonthlyRemaining(uid: string, kind: UsageKind, tier: Tier): Promise<number> {
  const used = await getMonthlyUsage(uid, kind);
  const limit = getMonthlyLimit(tier, kind);
  return Math.max(0, limit - used);
}

/** 📈 Increment usage for this month (and total lifetime).
 *  Supports negative increments for refunds (no clamping).
 */
export async function incrementMonthlyUsage(uid: string, kind: UsageKind, by = 1): Promise<void> {
  if (!Number.isFinite(by) || by === 0) return;
  const key = monthKey();
  const updates: Record<string, any> = {
    total: FieldValue.increment(by),
    [key]: FieldValue.increment(by),
  };
  await firestore.doc(usagePath(uid, kind)).set(updates, { merge: true });
}

/** 🧹 Reset usage for the current month (manual/admin tool) */
export async function resetMonthlyUsage(uid: string, kind: UsageKind): Promise<void> {
  const key = monthKey();
  await firestore.doc(usagePath(uid, kind)).set({ [key]: 0 }, { merge: true });
}

/* ────────────────────────────────────────────────
   🚦 Policy Enforcement
   ──────────────────────────────────────────────── */

/** Get resolved tier string from Firestore (normalised) */
export async function getResolvedTier(uid: string): Promise<Tier> {
  const snap = await firestore.collection("users").doc(uid).get();
  const raw = (snap.data()?.tier as string | undefined)?.toLowerCase().trim();
  if (raw === "home_chef" || raw === "master_chef") return raw;
  return "none";
}

/** Generic policy check (no increment) — useful for read-only checks */
export async function enforcePolicy(uid: string, kind: UsageKind): Promise<void> {
  const tier = await getResolvedTier(uid);
  if (tier === "none") {
    throw new HttpsError("permission-denied", "SUB_REQUIRED: Subscription required.");
  }
  const used = await getMonthlyUsage(uid, kind);
  const limit = getMonthlyLimit(tier, kind);
  if (used >= limit) {
    throw new HttpsError("resource-exhausted", `MONTHLY_LIMIT: ${errorCodeByKind[kind]}`);
  }
}

/** ✅ Transactional consume: atomically checks + increments.
 *  Prevents two concurrent requests from overshooting the cap.
 */
export async function enforceAndConsume(uid: string, kind: UsageKind, by = 1): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;

  const tier = await getResolvedTier(uid);
  if (tier === "none") {
    throw new HttpsError("permission-denied", "SUB_REQUIRED: Subscription required.");
  }

  const docRef = firestore.doc(usagePath(uid, kind));
  const key = monthKey();
  const limit = getMonthlyLimit(tier, kind);

  await firestore.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const data = snap.exists ? (snap.data() ?? {}) : {};
    const current = Number(data[key] ?? 0);

    if (current + by > limit) {
      throw new HttpsError("resource-exhausted", `MONTHLY_LIMIT: ${errorCodeByKind[kind]}`);
    }

    tx.set(
      docRef,
      {
        total: FieldValue.increment(by),
        [key]: FieldValue.increment(by),
      },
      { merge: true }
    );
  });
}

/** 🍬 Convenience: transactional consume and return fresh numbers
 *  Great for callables so the client can update instantly without waiting for the listener.
 */
export async function enforceConsumeAndGet(
  uid: string,
  kind: UsageKind,
  by = 1
): Promise<{ used: number; limit: number; remaining: number; month: string }> {
  await enforceAndConsume(uid, kind, by);
  const month = monthKey();
  const [tier, used] = await Promise.all([
    getResolvedTier(uid),
    getMonthlyUsage(uid, kind),
  ]);
  const limit = getMonthlyLimit(tier, kind);
  return { used, limit, remaining: Math.max(0, limit - used), month };
}

/** ↩️ Safe decrements (e.g., refunds): clamp to 0 so month values never go negative */
export async function decrementMonthlyUsageClamp(uid: string, kind: UsageKind, by = 1) {
  if (!Number.isFinite(by) || by <= 0) return;
  const docRef = firestore.doc(usagePath(uid, kind));
  const key = monthKey();
  await firestore.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const cur = Number((snap.data() ?? {})[key] ?? 0);
    const next = Math.max(0, cur - by);
    const delta = next - cur; // <= 0
    tx.set(docRef, { total: FieldValue.increment(delta), [key]: next }, { merge: true });
  });
}

/** 📦 Fetch all usage (current month) in one go — handy for boot or admin panels */
export async function getAllUsageForUser(uid: string) {
  const kinds: UsageKind[] = ["recipeUsage", "translatedRecipeUsage", "imageUsage"];
  const out: Record<UsageKind, number> = {
    recipeUsage: 0,
    translatedRecipeUsage: 0,
    imageUsage: 0,
  };
  const key = monthKey();
  await Promise.all(
    kinds.map(async (k) => {
      const snap = await firestore.doc(usagePath(uid, k)).get();
      out[k] = snap.exists ? Number(snap.data()?.[key] ?? 0) : 0;
    })
  );
  return out;
}

/** Convenience wrappers (discouraged for new code) */
export async function enforceTranslatedRecipePolicy(uid: string): Promise<void> {
  await enforcePolicy(uid, "translatedRecipeUsage");
}
export async function enforceGptRecipePolicy(uid: string): Promise<void> {
  await enforcePolicy(uid, "recipeUsage");
}
export async function enforceImagePolicy(uid: string): Promise<void> {
  await enforcePolicy(uid, "imageUsage");
}