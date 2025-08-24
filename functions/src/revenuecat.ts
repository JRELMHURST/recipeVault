// functions/src/revenuecat.ts
import * as crypto from "crypto";
import { Tier, productToTier } from "./mapping.js";

/** Types for RevenueCat payloads (unchanged) */
export interface Entitlement {
  is_active?: boolean;
  product_identifier?: string;
  [key: string]: any;
}
export interface Subscription {
  expires_date?: string;
  product_identifier?: string;
  [key: string]: any;
}
export interface RCSubscriber {
  entitlements?: Record<string, Entitlement>;
  subscriptions?: Record<string, Subscription>;
  original_app_user_id?: string;
  [key: string]: any;
}
export interface RCWebhookPayload {
  event?: { type?: string; id?: string };
  app_user_id?: string;
  subscriber?: RCSubscriber;
  product_id?: string;
  [key: string]: any;
}

/** ===== Active product resolution (centralised) ===== */

/** Resolve from a full webhook payload */
export function resolveActiveProductId(payload: RCWebhookPayload): string | null {
  return resolveActiveProductIdFromSubscriber(payload.subscriber ?? {}, payload.product_id);
}

/**
 * Resolve the currently active productId from a RevenueCat subscriber object.
 * Prefers entitlements, then optional directProductId hint, then subscriptions.
 */
export function resolveActiveProductIdFromSubscriber(
  subscriber: RCSubscriber,
  directProductId?: string | null
): string | null {
  if (!subscriber) {
    console.warn("[RC] resolveActiveProductIdFromSubscriber → no subscriber object");
    return null;
  }

  const entitlements = subscriber.entitlements ?? {};
  const subs = subscriber.subscriptions ?? {};

  // 🔍 Snapshot keys for debugging
  console.info("[RC] Subscriber snapshot", {
    entitlementKeys: Object.keys(entitlements),
    subscriptionKeys: Object.keys(subs),
    directProductId,
  });

// 1) Entitlements (source of truth per RevenueCat)
for (const [key, ent] of Object.entries(entitlements)) {
  console.info("[RC DEBUG] Checking entitlement", {
    entitlementKey: key,
    entitlement: ent,
  });

  if ((ent?.is_active || ent?.isActive) && ent?.product_identifier) {
    console.info("[RC] Resolved via entitlement", {
      entitlementKey: key,
      productId: ent.product_identifier,
    });
    return String(ent.product_identifier);
  }
}

  // 2) Direct productId hint
  if (directProductId) {
    console.info("[RC] Resolved via directProductId", directProductId);
    return String(directProductId);
  }

  // 3) Subscriptions fallback (still valid by expiry)
  for (const [pid, sub] of Object.entries(subs)) {
    const expiresAt = sub?.expires_date ? new Date(sub.expires_date) : null;
    const isActive = !expiresAt || expiresAt > new Date();
    if (isActive) {
      console.info("[RC] Resolved via subscription", { productId: pid, expiresAt });
      return String(pid);
    }
  }

  // Nothing found
  console.warn("[RC] No active entitlement or subscription found → returning null");
  return null;
}

/** Normalise `app_user_id` → Firebase UID (unchanged) */
export function resolveAppUserId(payload: RCWebhookPayload): string | null {
  if (payload.app_user_id) return String(payload.app_user_id);
  if (payload.subscriber?.original_app_user_id) {
    return String(payload.subscriber.original_app_user_id);
  }
  return null;
}

/** Map product → tier */
export function resolveTierFromPayload(payload: RCWebhookPayload): {
  uid: string | null;
  productId: string | null;
  tier: Tier;
} {
  const uid = resolveAppUserId(payload);
  const productId = resolveActiveProductId(payload);
  const tier = productToTier(productId);
  return { uid, productId, tier };
}

/** ─────────────────────────────────────────────────────────
 *  Shared hash helper so webhook + callable stay identical
 *  Accepts Firestore Timestamp | Date | string | null | unknown.
 *  ───────────────────────────────────────────────────────── */

function normaliseDateLike(v: unknown): string | null {
  if (v == null) return null;

  if (v instanceof Date) return v.toISOString();

  // Firestore Timestamp (duck-typed)
  const anyV: any = v as any;
  if (typeof anyV?.toDate === "function") {
    try {
      const d = anyV.toDate();
      if (d instanceof Date) return d.toISOString();
    } catch {
      // ignore
    }
  }
  if (typeof anyV?.seconds === "number") {
    const ms =
      anyV.seconds * 1000 +
      (typeof anyV.nanoseconds === "number" ? anyV.nanoseconds / 1e6 : 0);
    return new Date(ms).toISOString();
  }

  if (typeof v === "string") return v;

  return null;
}

/** Stable entitlement hash (used by callable + webhook) */
export function computeEntitlementHash(input: {
  productId: string | null | undefined;
  tier: Tier;
  entitlementStatus?: string | null | undefined;
  graceUntil?: unknown;
}): string {
  const payload = {
    productId: (input.productId ?? "none").toLowerCase(),
    tier: input.tier,
    status: input.entitlementStatus ?? null,
    graceUntil: normaliseDateLike(input.graceUntil),
  };
  return crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}