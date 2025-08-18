import fetch from "node-fetch";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/** 🔐 Internal tiers */
export type Tier = "home_chef" | "master_chef" | "none";

interface RevenueCatEntitlement {
  product_identifier: string;
  expires_date?: string | null;         // ISO string or null (non-expiring)
  period_type?: "normal" | "trial" | "intro";
}

interface RevenueCatResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
  };
}

// Map RC products -> internal tiers
const ENTITLEMENT_TIER_MAP: Record<string, Exclude<Tier, "none">> = {
  home_chef_monthly: "home_chef",
  master_chef_monthly: "master_chef",
  master_chef_yearly: "master_chef",
};

// Simple priority so we pick the highest tier if multiple
const TIER_PRIORITY: Record<Tier, number> = {
  none: 0,
  home_chef: 1,
  master_chef: 2,
};

function isActive(expires: string | null | undefined): boolean {
  if (!expires) return true; // non-expiring or lifetime
  const t = Date.parse(expires);
  if (Number.isNaN(t)) return false;
  return t > Date.now();
}

export async function getUserEntitlementFromRevenueCat(uid: string): Promise<Tier> {
  const apiKey = process.env.REVENUECAT_SECRET_KEY;
  if (!apiKey) {
    throw new Error("❌ REVENUECAT_SECRET_KEY is not set in environment.");
  }

  const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`;
  console.log(`📡 RevenueCat lookup → UID: ${uid}`);

  let tier: Tier = "none";
  let productId: string | null = null;

  try {
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      console.error(`❌ RevenueCat request failed: ${response.status} ${response.statusText}`);
      await saveToFirestore(uid, tier, productId);
      return tier;
    }

    const data = (await response.json()) as RevenueCatResponse;
    const entitlements = data.subscriber?.entitlements;

    if (!entitlements || Object.keys(entitlements).length === 0) {
      console.log("ℹ️ No entitlements on account — defaulting to 'none'");
      await saveToFirestore(uid, tier, productId);
      return tier;
    }

    // Evaluate all entitlements, keep the highest active one
    for (const [key, ent] of Object.entries(entitlements)) {
      const product = ent.product_identifier;
      const mapped = ENTITLEMENT_TIER_MAP[product];
      const active = isActive(ent.expires_date);

      console.log(
        `🧾 Entitlement '${key}': product=${product}, active=${active}, expires=${ent.expires_date ?? "n/a"}`
      );

      if (!mapped || !active) continue;

      if (TIER_PRIORITY[mapped] > TIER_PRIORITY[tier]) {
        tier = mapped;
        productId = product;
      }
    }

    if (tier === "none") {
      console.warn("⚠️ No active, recognized entitlements — falling back to 'none'");
    } else {
      console.log(`🎯 Resolved UID ${uid} → tier=${tier} via ${productId}`);
    }

    await saveToFirestore(uid, tier, productId);
    return tier;
  } catch (error) {
    console.error("❌ RevenueCat lookup failed:", error);
    await saveToFirestore(uid, tier, productId);
    return tier;
  }
}

async function saveToFirestore(uid: string, tier: Tier, productId: string | null): Promise<void> {
  try {
    await getFirestore()
      .collection("users")
      .doc(uid)
      .set(
        {
          tier,
          productId: productId ?? null,
          entitlementCheckedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    console.log("✅ Synced entitlement to Firestore");
  } catch (err) {
    console.error("❌ Failed to write user entitlement to Firestore:", err);
  }
}