// functions/src/policy.ts
import {
  enforceAndConsume,
  getResolvedTier,             // ✅ single source of truth for tier
  getMonthlyUsage,
  getMonthlyRemaining,
  incrementMonthlyUsage,       // ⚠️ only for refunds or non-transactional bumps
} from "./usage_service.js";

// Re-export tier/usage helpers (convenience for callers)
export { getResolvedTier, getMonthlyUsage, getMonthlyRemaining };

/* ────────────────────────────────────────────────
   🚦 Transactional enforcement policies
   ──────────────────────────────────────────────── */

/** Consume 1 GPT/recipe credit (atomic) */
export async function enforceGptRecipePolicy(uid: string): Promise<void> {
  await enforceAndConsume(uid, "aiUsage", 1);
}

/** Consume 1 translated recipe credit (atomic) */
export async function enforceTranslatedRecipePolicy(uid: string): Promise<void> {
  await enforceAndConsume(uid, "translatedRecipeUsage", 1);
}

/** Consume N image upload credits (atomic) */
export async function enforceImageUploadPolicy(uid: string, by: number): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;
  await enforceAndConsume(uid, "imageUsage", by);
}

/* ────────────────────────────────────────────────
   🕰️ Legacy non-transactional incrementers (discouraged)
   ──────────────────────────────────────────────── */

export async function incrementGptRecipeUsage(uid: string): Promise<void> {
  // ⚠️ Prefer enforceGptRecipePolicy() instead (atomic)
  await incrementMonthlyUsage(uid, "aiUsage", 1);
}

export async function incrementTranslatedRecipeUsage(uid: string): Promise<void> {
  // ⚠️ Prefer enforceTranslatedRecipePolicy() instead (atomic)
  await incrementMonthlyUsage(uid, "translatedRecipeUsage", 1);
}

export async function incrementImageUploadUsage(uid: string, by: number): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;
  await incrementMonthlyUsage(uid, "imageUsage", by);
}