// functions/src/reconcile.ts
import { firestore, Timestamp, FieldValue } from "./firebase.js";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import {
  resolveActiveProductIdFromSubscriber,
  computeEntitlementHash,
} from "./revenuecat.js";
import { toResult } from "./reconcile_entitlement.js";
import type { RCSubscriber } from "./revenuecat.js";
import type { Tier } from "./types.js";

const db = firestore;

type ReconcilePayload = {
  uid: string;
  productId: string | null;
  tier: Tier;
  status: "active" | "inactive";
  /** ISO-8601 string or null (never a Date object) */
  expiresAtIso: string | null;
  /** ISO-8601 string or null (never a Date object) */
  graceUntilIso: string | null;
  isInGrace: boolean;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Simple exponential backoff helper */
async function withRetries<T>(
  fn: () => Promise<Response | T>,
  retries = 3,
  baseDelayMs = 500
): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fn();
      if (res instanceof Response) {
        if (res.ok) return (res as unknown) as T;
        if (res.status === 404) return (res as unknown) as T;
        if (res.status >= 400 && res.status < 500) {
          throw new HttpsError("failed-precondition", `RC ${res.status} ${res.statusText}`);
        }
        throw new Error(`Transient HTTP ${res.status} ${res.statusText}`);
      }
      return res as T;
    } catch (err) {
      lastErr = err;
      if (attempt === retries) break;
      const backoff = baseDelayMs * 2 ** attempt;
      console.warn(`[RC Reconcile] ⚠️ Attempt ${attempt + 1} failed, retrying in ${backoff}ms…`, err);
      await sleep(backoff);
    }
  }
  throw lastErr as Error;
}

export const reconcileUserFromRC = onCall(
  {
    // region is set globally via setGlobalOptions in firebase.ts
    enforceAppCheck: true,
    secrets: ["RC_API_KEY"],
    cors: false,
  },
  async (request: CallableRequest): Promise<ReconcilePayload> => {
    try {
      // Emulator convenience: allow calls without auth
      const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
      if (isEmulator && !request.auth) {
        console.warn("[RC Reconcile] ⚠️ Emulator mode: injecting fake auth");
        (request as any).auth = {
          uid: (request.data?.uid as string) ?? "test-user",
          token: { admin: true },
        };
      }

      if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "You must be signed in.");
      }

      const callerUid = request.auth.uid;
      const isAdmin = !!request.auth.token?.admin;
      const bodyUid = request.data?.uid ? String(request.data.uid) : "";

      const targetUid = isAdmin
        ? bodyUid || (() => { throw new HttpsError("invalid-argument", "Admin calls require { uid }"); })()
        : bodyUid && bodyUid !== callerUid
        ? (() => { throw new HttpsError("permission-denied", "Clients may only reconcile their own account."); })()
        : callerUid;

      const apiKey = process.env.RC_API_KEY;
      if (!apiKey) throw new HttpsError("failed-precondition", "Missing RC API key");

      // ── Fetch RC subscriber ──────────────────────────────
      const rcResp = (await withRetries(() =>
        fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(targetUid)}`, {
          headers: { Authorization: `Bearer ${apiKey}` },
        })
      )) as Response;

      if (rcResp.status === 404) {
        console.warn(`[RC Reconcile] No RC subscriber for ${targetUid}`);

        const entitlementHash = computeEntitlementHash({
          productId: "none",
          tier: "none" as Tier,
          entitlementStatus: "inactive",
          graceUntil: null,
        });

        await withRetries(() =>
          db.doc(`users/${targetUid}`).set(
            {
              productId: "none",
              tier: "none",
              entitlementStatus: "inactive",
              expiresAt: null,
              graceUntil: null,
              isInGrace: false,
              entitlementHash,
              lastEntitlementEventAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          )
        );

        return {
          uid: targetUid,
          productId: null,
          tier: "none",
          status: "inactive",
          expiresAtIso: null,
          graceUntilIso: null,
          isInGrace: false,
        };
      }

      const json = (await rcResp.json()) as { subscriber?: RCSubscriber };
      const subscriber: RCSubscriber = json?.subscriber ?? { entitlements: {}, subscriptions: {} };

      console.info("[RC Reconcile] Raw RC subscriber", {
        uid: targetUid,
        entitlements: Object.keys(subscriber.entitlements ?? {}),
        subscriptions: Object.keys(subscriber.subscriptions ?? {}),
      });

      // ── Resolve entitlement & map to business result ─────
      const productId = resolveActiveProductIdFromSubscriber(subscriber);
      const activeSub = productId ? subscriber.subscriptions?.[productId] : undefined;
      const expiresAtIso = activeSub?.expires_date ?? undefined;
      const expiresAt = expiresAtIso ? new Date(expiresAtIso) : null;

      // Some RC responses expose `unsubscribe_detected_at`
      const eventType = (activeSub as any)?.unsubscribe_detected_at ? "CANCELLATION" : null;

      const result = toResult(productId, { expiresAt, eventType, graceDays: 3 });
      const safeProductId = (result.productId ?? "none").toLowerCase();

      // Normalize to "active" | "inactive" for client
      const normalizedStatus: "active" | "inactive" =
        result.entitlementStatus === "active" ? "active" : "inactive";

      // Hash to detect changes
      const entitlementHash = computeEntitlementHash({
        productId: result.productId ?? "none",
        tier: result.tier as Tier,
        entitlementStatus: normalizedStatus,
        graceUntil: result.graceUntil ?? null,
      });

      const userRef = db.doc(`users/${targetUid}`);
      const snap = await userRef.get();
      const prevHash: string | undefined = snap.exists
        ? (snap.get("entitlementHash") as string | undefined)
        : undefined;

      const needsBackfill =
        !snap.exists ||
        !snap.get("tier") ||
        !snap.get("productId") ||
        !snap.get("entitlementStatus");

      const changed = prevHash !== entitlementHash;

      console.info("[RC Reconcile] Decision", {
        uid: targetUid,
        productId: result.productId,
        mappedTier: result.tier,
        entitlementStatus: normalizedStatus,
        prevHash,
        newHash: entitlementHash,
        changed,
        needsBackfill,
      });

      if (changed || needsBackfill) {
        await withRetries(() =>
          userRef.set(
            {
              productId: safeProductId,
              tier: result.tier as Tier,
              entitlementStatus: normalizedStatus,
              // Store as Firestore Timestamp
              expiresAt: result.expiresAt ? Timestamp.fromDate(result.expiresAt) : null,
              graceUntil: result.graceUntil ? Timestamp.fromDate(result.graceUntil) : null,
              isInGrace: !!(result.graceUntil && result.graceUntil > new Date()),
              entitlementHash,
              lastEntitlementEventAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          )
        );
        console.info(`[RC Reconcile] ✅ Firestore updated for ${targetUid} → ${result.tier}`);
      } else {
        console.info(`[RC Reconcile] ℹ️ No Firestore update for ${targetUid}`);
      }

      // Callable payload: only primitives / JSON-safe types
      const payload: ReconcilePayload = {
        uid: targetUid,
        productId: result.productId ?? null,
        tier: result.tier as Tier,
        status: normalizedStatus,
        expiresAtIso: result.expiresAt ? result.expiresAt.toISOString() : null,
        graceUntilIso: result.graceUntil ? result.graceUntil.toISOString() : null,
        isInGrace: !!(result.graceUntil && result.graceUntil > new Date()),
      };

      return payload;
    } catch (err: any) {
      if (err instanceof HttpsError) throw err;
      console.error("[RC Reconcile] ❌ Unhandled error", err);
      throw new HttpsError("unknown", err?.message ?? "Unknown error");
    }
  }
);