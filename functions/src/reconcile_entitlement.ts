// functions/src/reconcile_entitlement.ts
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
  /** May remain null; set in future when you add grace logic. */
  graceUntil: Timestamp | Date | string | null;
};

function toDate(d: unknown): Date | null {
  if (!d) return null;
  if (d instanceof Date) return d;
  const anyD: any = d as any;
  if (typeof anyD?.toDate === "function") {
    try { const dd = anyD.toDate(); return dd instanceof Date ? dd : null; } catch { return null; }
  }
  if (typeof d === "string") {
    const parsed = new Date(d);
    return isNaN(+parsed) ? null : parsed;
  }
  return null;
}

export function toResult(productId: string | null, ctx: ReconcileContext = {}): ReconcileResult {
  const tier = productToTier(productId);

  // Default status logic (current behaviour): active iff tier != none
  let entitlementStatus: EntitlementStatus = tier === "none" ? "none" : "active";
  let graceUntil: ReconcileResult["graceUntil"] = null;

  // Optional richer logic using expiry and event hints
  const expires = toDate(ctx.expiresAt);
  const now = new Date();

  if (tier !== "none" && expires && expires <= now) {
    entitlementStatus = "expired";
    if (ctx.graceDays && ctx.graceDays > 0) {
      const g = new Date(expires);
      g.setDate(g.getDate() + ctx.graceDays);
      graceUntil = g;
      if (g > now) entitlementStatus = "active"; // still in grace window
    }
  }

  // You could also branch on ctx.eventType if desired

  return { productId, tier, entitlementStatus, graceUntil };
}