import fetch from "node-fetch";
import { getFirestore } from "firebase-admin/firestore";

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

// ✅ Only valid, paid entitlements mapped to internal tiers
const ENTITLEMENT_TIER_MAP: Record<string, 'home_chef' | 'master_chef'> = {
  home_chef_monthly: "home_chef",
  master_chef_monthly: "master_chef",
  master_chef_yearly: "master_chef",
};

/**
 * 🔍 Queries RevenueCat for the user's active entitlement and syncs tier to Firestore.
 * Falls back to 'free' if no valid entitlement is found.
 */
export async function getUserEntitlementFromRevenueCat(
  uid: string
): Promise<'free' | 'home_chef' | 'master_chef'> {
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
      await saveToFirestore(uid, 'free', null);
      return 'free';
    }

    const data = (await response.json()) as RevenueCatResponse;
    const entitlements = data.subscriber?.entitlements;

    if (!entitlements || Object.keys(entitlements).length === 0) {
      console.log(`ℹ️ No entitlements found for UID: ${uid} — defaulting to 'free'`);
      await saveToFirestore(uid, 'free', null);
      return 'free';
    }

    for (const [key, entitlement] of Object.entries(entitlements)) {
      const { product_identifier, expires_date, period_type } = entitlement;

      console.log(`🧾 Entitlement '${key}':`);
      console.log(`   ↪︎ Product: ${product_identifier}`);
      console.log(`   ↪︎ Period: ${period_type}`);
      console.log(`   ↪︎ Expires: ${expires_date ?? "n/a"}`);

      if (ENTITLEMENT_TIER_MAP[product_identifier]) {
        const tier = ENTITLEMENT_TIER_MAP[product_identifier];

        console.log(`🎯 RevenueCat resolved UID ${uid} → ${tier} (via ${product_identifier})`);

        await saveToFirestore(uid, tier, product_identifier);
        return tier;
      }
    }

    console.warn(`⚠️ No recognised entitlements matched for UID: ${uid}`);
    await saveToFirestore(uid, 'free', null);
    return 'free';

  } catch (error) {
    console.error("❌ Failed to fetch entitlement from RevenueCat:", error);
    await saveToFirestore(uid, 'free', null);
    return 'free';
  }
}

async function saveToFirestore(
  uid: string,
  tier: 'free' | 'home_chef' | 'master_chef',
  entitlementId: string | null,
): Promise<void> {
  try {
    await getFirestore()
      .collection("users")
      .doc(uid)
      .set(
        {
          tier,
          entitlementId: entitlementId ?? null,
        },
        { merge: true }
      );

    console.log(`✅ Synced entitlementId and tier to Firestore`);
  } catch (err) {
    console.error("❌ Failed to write user entitlement to Firestore:", err);
  }
}