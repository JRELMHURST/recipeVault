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

export async function getUserEntitlementFromRevenueCat(
  uid: string
): Promise<string | null> {
  const apiKey = process.env.REVENUECAT_API_KEY;
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${uid}`,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: 'application/json',
      },
    }
  );

  if (!response.ok) return null;

  const data = (await response.json()) as RevenueCatResponse;
  const entitlements = data.subscriber?.entitlements;
  if (!entitlements || Object.keys(entitlements).length === 0) return null;

  const map: Record<string, string> = {
    master_chef_yearly: 'master_chef',
    master_chef_monthly: 'master_chef',
    home_chef_monthly: 'home_chef',
    taster_trial: 'taster',
  };

  for (const key of Object.keys(entitlements)) {
    const productId = entitlements[key].product_identifier;
    if (map[productId]) {
      return map[productId];
    }
  }

  return null;
}