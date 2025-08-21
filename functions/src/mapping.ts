// functions/src/mapping.ts

/** Internal subscription tiers in RecipeVault */
export type Tier = "home_chef" | "master_chef" | "none";

/**
 * Mapping from RevenueCat product identifiers → internal Tier.
 * Always lowercased to avoid mismatches.
 */
export const PRODUCT_TO_TIER: Readonly<Record<string, Tier>> = {
  // Home Chef (monthly only, but collapse all aliases)
  "home_chef_monthly": "home_chef",
  "rc_homechef_monthly_2025": "home_chef",

  // Master Chef (monthly + yearly)
  "master_chef_monthly": "master_chef",
  "master_chef_yearly": "master_chef",
  "rc_masterchef_monthly_2025": "master_chef",
  "rc_masterchef_annual_2025": "master_chef",
} as const;

/**
 * Reverse mapping: Tier → list of valid productIds (all lowercase)
 */
export const TIER_TO_PRODUCTS: Readonly<Record<Tier, string[]>> = {
  home_chef: ["home_chef_monthly", "rc_homechef_monthly_2025"],
  master_chef: [
    "master_chef_monthly",
    "master_chef_yearly",
    "rc_masterchef_monthly_2025",
    "rc_masterchef_annual_2025",
  ],
  none: [],
} as const;

export function productToTier(productId?: string | null): Tier {
  if (!productId) return "none";
  const key = String(productId).toLowerCase().trim();
  return PRODUCT_TO_TIER[key] ?? "none";
}

export function tierToProducts(tier: Tier): string[] {
  return TIER_TO_PRODUCTS[tier] ?? [];
}

export function isProductInTier(
  productId: string | null | undefined,
  tier: Tier
): boolean {
  if (!productId) return false;
  const key = String(productId).toLowerCase().trim();
  return tierToProducts(tier).includes(key);
}