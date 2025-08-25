/** 📦 Internal subscription tiers in RecipeVault */
export const ALL_TIERS = ["home_chef", "master_chef", "none"] as const;
export type Tier = typeof ALL_TIERS[number];

/**
 * 🔑 Central source of truth:
 * Map RevenueCat product identifiers → internal Tier.
 * Always lowercase to avoid mismatches.
 */
export const PRODUCT_TO_TIER: Readonly<Record<string, Tier>> = {
  // Home Chef (monthly)
  "home_chef_monthly": "home_chef",
  "rc_homechef_monthly_2025": "home_chef",

  // Master Chef (monthly + yearly)
  "master_chef_monthly": "master_chef",
  "master_chef_yearly": "master_chef",
  "rc_masterchef_monthly_2025": "master_chef",
  "rc_masterchef_annual_2025": "master_chef",
} as const;

/**
 * 🔄 Derived reverse mapping: Tier → list of valid productIds
 * Ensures we never drift between maps.
 */
export const TIER_TO_PRODUCTS: Readonly<Record<Tier, string[]>> = Object.freeze({
  home_chef: Object.keys(PRODUCT_TO_TIER).filter((k) => PRODUCT_TO_TIER[k] === "home_chef"),
  master_chef: Object.keys(PRODUCT_TO_TIER).filter((k) => PRODUCT_TO_TIER[k] === "master_chef"),
  none: [],
});

/** 🔧 Normalise productId for consistent lookups */
function normaliseProductId(id: string | null | undefined): string | null {
  return id ? String(id).toLowerCase().trim() : null;
}

/** Resolve productId → tier */
export function productToTier(productId?: string | null): Tier {
  const key = normaliseProductId(productId);
  return key ? PRODUCT_TO_TIER[key] ?? "none" : "none";
}

/** Resolve tier → valid productIds */
export function tierToProducts(tier: Tier): string[] {
  return TIER_TO_PRODUCTS[tier] ?? [];
}

/** Check if productId belongs to a given tier */
export function isProductInTier(
  productId: string | null | undefined,
  tier: Tier
): boolean {
  const key = normaliseProductId(productId);
  return key ? TIER_TO_PRODUCTS[tier].includes(key) : false;
}

/** 🚨 Safety: Assert that every tier except "none" has at least one product */
(function assertTierCoverage() {
  (ALL_TIERS.filter((t) => t !== "none")).forEach((t) => {
    if (TIER_TO_PRODUCTS[t].length === 0) {
      throw new Error(`Tier ${t} has no mapped products in PRODUCT_TO_TIER`);
    }
  });
})();