// functions/src/types.ts

/**
 * Subscription tier (business concept).
 * Used in both Firestore and client logic.
 */
export type Tier = 'none' | 'home_chef' | 'master_chef';

/**
 * Internal entitlement status returned from RC / toResult.
 * Can include "none" as a transitional state.
 */
export type EntitlementStatus = 'active' | 'inactive' | 'none';

/**
 * Narrowed status that we expose in public payloads.
 * Only "active" | "inactive".
 */
export type PublicStatus = 'active' | 'inactive';

/**
 * Shape of the reconcile response returned to clients.
 */
export interface ReconcilePayload {
  uid: string;
  productId: string | null;
  tier: Tier;
  status: PublicStatus;  // <= only active/inactive leaves "none" internal
  expiresAt: Date | null;
  graceUntil: Date | null;
  isInGrace: boolean;
}