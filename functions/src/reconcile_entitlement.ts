// functions/src/reconcile_entitlement.ts
import { productToTier } from "./mapping.js";

export type ReconcileResult = {
  productId: string | null;
  tier: "home_chef" | "master_chef" | "none";
  entitlementStatus: "active" | "expired" | "none";
  graceUntil: FirebaseFirestore.Timestamp | null;
};

export function toResult(productId: string | null): ReconcileResult {
  const tier = productToTier(productId);
  const entitlementStatus: ReconcileResult["entitlementStatus"] = tier === "none" ? "none" : "active";
  return { productId, tier, entitlementStatus, graceUntil: null };
}