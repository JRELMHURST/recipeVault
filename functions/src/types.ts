// functions/src/types.ts

/**
 * Subscription tier (business concept).
 * Used in both Firestore and client logic.
 */
export type Tier = "none" | "home_chef" | "master_chef";

/**
 * Internal entitlement status returned from RC / toResult.
 * Can include "none" as a transitional state.
 */
export type EntitlementStatus = "active" | "inactive" | "none";

/**
 * Narrowed status that we expose in public payloads.
 * Only "active" | "inactive".
 */
export type PublicStatus = "active" | "inactive";

/**
 * Shape of the reconcile response returned to clients.
 * Dates are always sent as ISO 8601 strings (UTC).
 */
export interface ReconcilePayload {
  uid: string;
  productId: string | null;   // RC productIdentifier (or null if none)
  tier: Tier;                 // normalised internal tier
  status: PublicStatus;       // exposed entitlement status
  expiresAtIso: string | null;   // ISO string for expiry
  graceUntilIso: string | null;  // ISO string for grace
  isInGrace: boolean;            // quick flag for client UI
}