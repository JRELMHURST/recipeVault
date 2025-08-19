// functions/src/mapping.ts

/**
 * Internal subscription tiers in RecipeVault
 */
export type Tier = "home_chef" | "master_chef" | "none";

/**
 * Mapping from RevenueCat product identifiers → internal Tier.
 * Always normalise keys to lowercase.
 */
export const PRODUCT_TO_TIER: Record<string, Tier> = {
  "home_chef_monthly": "home_chef",
  "home_chef_yearly": "home_chef",   // ✅ future-proof in case you add yearly
  "master_chef_monthly": "master_chef",
  "master_chef_yearly": "master_chef",
};

/**
 * Convert a RevenueCat productId into a Tier
 *
 * @param productId - RevenueCat product identifier (may be null/undefined)
 * @returns the internal Tier or 'none' if unmapped
 */
export function productToTier(productId?: string | null): Tier {
  if (!productId) return "none";

  const key = String(productId).toLowerCase().trim();
  return PRODUCT_TO_TIER[key] ?? "none";
}