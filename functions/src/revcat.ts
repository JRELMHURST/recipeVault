// functions/src/revcat.ts
import fetch from 'node-fetch';

interface RevenueCatResponse {
  subscriber?: {
    entitlements?: Record<string, any>;
  };
}

export async function getUserEntitlementFromRevenueCat(
  uid: string
): Promise<string | null> {
  const apiKey = process.env.REVENUECAT_API_KEY;
  const userId = uid;

  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${userId}`,
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
  if (!entitlements) return 'none';

  if (entitlements.master_chef_yearly) return 'master_chef';
  if (entitlements.master_chef_monthly) return 'master_chef';
  if (entitlements.home_chef_monthly) return 'home_chef';
  if (entitlements.taster_trial) return 'taster';

  return 'none';
}