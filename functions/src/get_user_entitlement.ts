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

// 🧭 Define entitlement-to-tier mapping
const ENTITLEMENT_TIER_MAP: Record<string, string> = {
  master_chef_yearly: "master_chef",
  master_chef_monthly: "master_chef",
  home_chef_monthly: "home_chef",
  taster_trial: "taster",
};

/**
 * 🔍 Queries RevenueCat to get the user's active tier and saves it to Firestore.
 * Returns the mapped tier (e.g. 'master_chef') or null.
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
  console.log(`ℹ️ No entitlements found for UID: ${uid} — skipping update`);
  return null; // 👈 No Firestore mutation
}

    for (const [key, entitlement] of Object.entries(entitlements)) {
      const { product_identifier, expires_date, period_type } = entitlement;

      console.log(`🧾 Entitlement '${key}':`);
      console.log(`   ↪︎ Product: ${product_identifier}`);
      console.log(`   ↪︎ Period: ${period_type}`);
      console.log(`   ↪︎ Expires: ${expires_date ?? "n/a"}`);

      if (product_identifier && ENTITLEMENT_TIER_MAP[product_identifier]) {
        const tier = ENTITLEMENT_TIER_MAP[product_identifier];
        const isTrial =
          period_type === "trial" || period_type === "intro";

        console.log(`🎯 RevenueCat resolved UID ${uid} → ${tier} (via ${product_identifier})`);

        await saveToFirestore(uid, tier, product_identifier, isTrial);
        return tier;
      }
    }

    console.warn(`⚠️ No recognised entitlements matched for UID: ${uid}`);
    await saveToFirestore(uid, 'none', null, false);
    return null;
  } catch (error) {
    console.error("❌ Failed to fetch entitlement from RevenueCat:", error);
    await saveToFirestore(uid, 'none', null, false);
    return null;
  }
}

async function saveToFirestore(
  uid: string,
  tier: string,
  entitlementId: string | null,
  trialActive: boolean
): Promise<void> {
  try {
    await getFirestore()
      .collection("users")
      .doc(uid)
      .set(
        {
          tier,
          entitlementId: entitlementId ?? null,
          trialActive,
        },
        { merge: true }
      );

    console.log(`✅ Synced entitlementId, tier, and trialActive to Firestore`);
  } catch (err) {
    console.error("❌ Failed to write user entitlement to Firestore:", err);
  }
}