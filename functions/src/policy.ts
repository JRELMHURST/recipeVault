// functions/src/policy.ts
import {
  enforceAndConsume,
  getResolvedTier,             // reuse single source of truth
  getMonthlyUsage,
  getMonthlyRemaining,
  incrementMonthlyUsage,       // only if you truly need non-transactional bumps
} from "./usage_service.js";

// Re-export tier if callers rely on this module for it
export { getResolvedTier, getMonthlyUsage, getMonthlyRemaining };

// 🚦 Transactional enforcement + consume (no races)
export async function enforceGptRecipePolicy(uid: string): Promise<void> {
  await enforceAndConsume(uid, "aiUsage", 1);
}

export async function enforceTranslationPolicy(uid: string): Promise<void> {
  await enforceAndConsume(uid, "translationUsage", 1);
}

export async function enforceImageUploadPolicy(uid: string, by: number): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;
  await enforceAndConsume(uid, "imageUsage", by);
}

// If legacy callers still call these, keep them but mark deprecated:
export async function incrementGptRecipeUsage(uid: string): Promise<void> {
  // Prefer enforceGptRecipePolicy which is atomic
  await incrementMonthlyUsage(uid, "aiUsage", 1);
}
export async function incrementTranslationUsage(uid: string): Promise<void> {
  await incrementMonthlyUsage(uid, "translationUsage", 1);
}
export async function incrementImageUploadUsage(uid: string, by: number): Promise<void> {
  if (!Number.isFinite(by) || by <= 0) return;
  await incrementMonthlyUsage(uid, "imageUsage", by);
}