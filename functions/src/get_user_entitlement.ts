import fetch from 'node-fetch';

interface RevenueCatEntitlement {
  product_identifier: string;
  expires_date?: string | null;
  period_type: 'normal' | 'trial' | 'intro';
}

interface RevenueCatResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
  };
}

/**
 * Queries RevenueCat to get the user's active entitlement.
 * Returns the RevenueCat product_identifier (e.g. 'master_chef_yearly') or null.
 */
export async function getUserEntitlementFromRevenueCat(
  uid: string
): Promise<string | null> {
  const apiKey = process.env.REVENUECAT_SECRET_KEY;
  if (!apiKey) throw new Error("REVENUECAT_SECRET_KEY is missing.");

  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${uid}`,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: 'application/json',
      },
    }
  );

  if (!response.ok) {
    console.error(`❌ RevenueCat error (${response.status}): ${response.statusText}`);
    return null;
  }

  const data = (await response.json()) as RevenueCatResponse;
  const entitlements = data.subscriber?.entitlements;
  if (!entitlements || Object.keys(entitlements).length === 0) {
    console.log(`ℹ️ No entitlements found for UID: ${uid}`);
    return null;
  }

  for (const key of Object.keys(entitlements)) {
    const productId = entitlements[key].product_identifier;
    if (productId) {
      console.log(`🎯 RevenueCat resolved UID ${uid} → ${productId}`);
      return productId;
    }
  }

  return null;
}