// functions/src/revenuecat.ts
import { Tier, productToTier } from "./mapping.js";

/**
 * Types for RevenueCat webhook payloads
 */
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
  event?: { type?: string };
  app_user_id?: string;
  subscriber?: RCSubscriber;
  product_id?: string;
  [key: string]: any;
}

/**
 * Resolve the active productId from RevenueCat payload.
 */
export function resolveActiveProductId(payload: RCWebhookPayload): string | null {
  const s = payload.subscriber ?? {};

  // 1) Check entitlements first
  if (s.entitlements) {
    for (const [, ent] of Object.entries(s.entitlements)) {
      if (ent?.is_active && ent?.product_identifier) {
        return String(ent.product_identifier);
      }
    }
  }

  // 2) Direct product_id (present in many webhook events)
  if (payload.product_id) return String(payload.product_id);

  // 3) Subscriptions fallback
  if (s.subscriptions) {
    for (const [pid, sub] of Object.entries(s.subscriptions)) {
      const expiresAt = sub?.expires_date ? new Date(sub.expires_date) : null;
      const isActive = !expiresAt || expiresAt > new Date();
      if (isActive) return String(pid);
    }
  }

  return null;
}

/**
 * Normalise `app_user_id` → Firebase UID
 */
export function resolveAppUserId(payload: RCWebhookPayload): string | null {
  if (payload.app_user_id) return String(payload.app_user_id);
  if (payload.subscriber?.original_app_user_id) {
    return String(payload.subscriber.original_app_user_id);
  }
  return null;
}

/**
 * Resolve UID, productId, and normalised tier
 */
export function resolveTierFromPayload(
  payload: RCWebhookPayload
): {
  uid: string | null;
  productId: string | null;
  tier: Tier;
} {
  const uid = resolveAppUserId(payload);
  const productId = resolveActiveProductId(payload);
  const tier = productToTier(productId);
  return { uid, productId, tier };
}