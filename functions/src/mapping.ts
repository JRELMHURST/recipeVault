/**
 * Internal subscription tiers in RecipeVault
 */
export type Tier = "home_chef" | "master_chef" | "none";

/**
 * Mapping from RevenueCat product identifiers → internal Tier.
 * Always normalise keys to lowercase.
 */
export const PRODUCT_TO_TIER: Readonly<Record<string, Tier>> = {
  "home_chef_monthly": "home_chef",
  "master_chef_monthly": "master_chef",
  "master_chef_yearly": "master_chef",
} as const;

/**
 * Reverse mapping: internal Tier → list of RevenueCat product identifiers
 */
export const TIER_TO_PRODUCTS: Readonly<Record<Tier, string[]>> = {
  home_chef: ["home_chef_monthly"],
  master_chef: ["master_chef_monthly", "master_chef_yearly"],
  none: [], // no RC products map to 'none'
} as const;

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

/**
 * Convert a Tier back to all known product identifiers
 *
 * @param tier - Internal Tier
 * @returns array of product identifiers for that tier
 */
export function tierToProducts(tier: Tier): string[] {
  return TIER_TO_PRODUCTS[tier] ?? [];
}

/**
 * Check if a given productId belongs to a specific Tier
 *
 * @param productId - RevenueCat product identifier
 * @param tier - Internal Tier
 * @returns true if the productId is in that tier
 */
export function isProductInTier(productId: string | null | undefined, tier: Tier): boolean {
  if (!productId) return false;
  return tierToProducts(tier).includes(String(productId).toLowerCase().trim());
}