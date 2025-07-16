// functions/src/get_user_entitlement.ts

import fetch from "node-fetch";

interface RevenueCatEntitlement {
  product_identifier: string;
  expires_date?: string | null;
  period_type: "normal" | "trial" | "intro";
}

interface RevenueCatResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
  };
}

/**
 * 🔍 Queries RevenueCat to get the user's active entitlement.
 * Returns the product_identifier (e.g. 'master_chef_yearly') or null.
 */
export async function getUserEntitlementFromRevenueCat(
  uid: string
): Promise<string | null> {
  const apiKey = process.env.REVENUECAT_SECRET_KEY;
  if (!apiKey) {
    throw new Error("❌ REVENUECAT_SECRET_KEY is not set in environment.");
  }

  const url = `https://api.revenuecat.com/v1/subscribers/${uid}`;
  console.log(`📡 Fetching entitlement from RevenueCat for UID: ${uid}`);

  try {
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      console.error(`❌ RevenueCat request failed: ${response.status} ${response.statusText}`);
      return null;
    }

    const data = (await response.json()) as RevenueCatResponse;
    const entitlements = data.subscriber?.entitlements;

    if (!entitlements || Object.keys(entitlements).length === 0) {
      console.log(`ℹ️ No entitlements found for UID: ${uid}`);
      return null;
    }

    for (const [key, entitlement] of Object.entries(entitlements)) {
      const { product_identifier, expires_date, period_type } = entitlement;

      console.log(`🧾 Entitlement '${key}':`);
      console.log(`   ↪︎ Product: ${product_identifier}`);
      console.log(`   ↪︎ Period: ${period_type}`);
      console.log(`   ↪︎ Expires: ${expires_date ?? "n/a"}`);

      if (product_identifier) {
        console.log(`🎯 RevenueCat resolved UID ${uid} → ${product_identifier}`);
        return product_identifier;
      }
    }

    return null;
  } catch (error) {
    console.error("❌ Failed to fetch entitlement from RevenueCat:", error);
    return null;
  }
}