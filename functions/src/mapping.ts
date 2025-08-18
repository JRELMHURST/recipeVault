// functions/src/mapping.ts

export type Tier = 'home_chef' | 'master_chef' | 'none';

export const PRODUCT_TO_TIER: Record<string, Tier> = {
  // normalise to lowercase keys
  'home_chef_monthly': 'home_chef',
  'master_chef_monthly': 'master_chef',
  'master_chef_yearly': 'master_chef',
};

export function productToTier(productId?: string | null): Tier {
  if (!productId) return 'none';
  const key = String(productId).toLowerCase();
  return PRODUCT_TO_TIER[key] ?? 'none';
}