import type { Timestamp } from "firebase-admin/firestore";
import { productToTier } from "./mapping.js";

export type EntitlementStatus = "active" | "expired" | "none";

export type ReconcileContext = {
  /** ISO string, Date, or Firestore Timestamp from RevenueCat expiry (optional). */
  expiresAt?: string | Date | Timestamp | null;
  /** RevenueCat event type hint (optional, e.g. "CANCELLATION", "BILLING_ISSUE", etc.). */
  eventType?: string | null;
  /** Optional grace window in days (default 0 = none). */
  graceDays?: number;
};

export type ReconcileResult = {
  productId: string | null;
  tier: "home_chef" | "master_chef" | "none";
  entitlementStatus: EntitlementStatus;
  graceUntil: Date | null; // always normalised to Date
  expiresAt: Date | null;  // stored alongside for audit/debug
  eventType?: string | null;
};

/** Safely converts Firestore Timestamp / string / Date → Date */
function toDate(d: unknown): Date | null {
  if (!d) return null;
  if (d instanceof Date) return d;
  const anyD: any = d as any;
  if (typeof anyD?.toDate === "function") {
    try {
      const dd = anyD.toDate();
      return dd instanceof Date ? dd : null;
    } catch {
      return null;
    }
  }
  if (typeof d === "string") {
    const parsed = new Date(d);
    return isNaN(+parsed) ? null : parsed;
  }
  return null;
}

/** Computes entitlement tier + status from RevenueCat context. */
export function toResult(
  productId: string | null,
  ctx: ReconcileContext = {}
): ReconcileResult {
  const tier = productToTier(productId);
  let entitlementStatus: EntitlementStatus = tier === "none" ? "none" : "active";

  const expires = toDate(ctx.expiresAt);
  const now = new Date();

  let graceUntil: Date | null = null;

  if (tier !== "none" && expires) {
    if (expires <= now) {
      entitlementStatus = "expired";
      if (ctx.graceDays && ctx.graceDays > 0) {
        const g = new Date(expires);
        g.setDate(g.getDate() + ctx.graceDays);
        graceUntil = g;
        if (g > now) entitlementStatus = "active"; // still in grace window
      }
    }
  }

  // Optional immediate downgrade on billing issue
  if (ctx.eventType === "BILLING_ISSUE" && entitlementStatus === "active") {
    entitlementStatus = "expired";
  }

  return {
    productId,
    tier,
    entitlementStatus,
    graceUntil,
    expiresAt: expires,
    eventType: ctx.eventType ?? null,
  };
}