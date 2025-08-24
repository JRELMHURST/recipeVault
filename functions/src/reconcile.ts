import admin, { firestore } from "./firebase.js";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { resolveActiveProductIdFromSubscriber, computeEntitlementHash } from "./revenuecat.js";
import { toResult } from "./reconcile_entitlement.js";

const db = firestore;

/**
 * Retry wrapper with exponential backoff.
 */
async function withRetries<T>(
  fn: () => Promise<Response | T>,
  retries = 3,
  baseDelayMs = 500
): Promise<T> {
  let lastErr: any;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const result = await fn();
      if (result instanceof Response) {
        if (result.ok) return result as unknown as T;
        if (result.status === 404) return result as unknown as T;
        if (result.status >= 400 && result.status < 500) {
          throw new HttpsError("failed-precondition", `Non-retriable ${result.status}`);
        }
        throw new Error(`Transient HTTP error: ${result.status}`);
      }
      return result as T;
    } catch (err) {
      lastErr = err;
      if (attempt === retries) break;
      const backoff = baseDelayMs * Math.pow(2, attempt);
      console.warn(`[RC Reconcile] ⚠️ Attempt ${attempt + 1} failed, retrying in ${backoff}ms...`, err);
      await new Promise((res) => setTimeout(res, backoff));
    }
  }
  throw lastErr;
}

export const reconcileUserFromRC = onCall(
  {
    region: "europe-west2",
    enforceAppCheck: true,
    secrets: ["RC_API_KEY"],   // ✅ declare secret dependency
  },
  async (request: CallableRequest) => {
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    if (isEmulator && !request.auth) {
      console.warn("[RC Reconcile] ⚠️ Emulator mode: injecting fake auth");
      request.auth = { uid: request.data?.uid ?? "test-user", token: { admin: true } as any };
    }

    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in");
    }

    const callerUid = request.auth.uid;
    const uidParam = request.data?.uid ? String(request.data.uid) : "";
    const targetUid =
      request.auth.token?.admin
        ? uidParam || (() => { throw new HttpsError("invalid-argument", "uid required for admin calls"); })()
        : uidParam && uidParam !== callerUid
        ? (() => { throw new HttpsError("permission-denied", "Clients may only reconcile their own account"); })()
        : callerUid;

    const apiKey = process.env.RC_API_KEY;
    if (!apiKey) throw new HttpsError("failed-precondition", "Missing RC API key");

    // ── Fetch subscriber from RC ──────────────────────
    const resp = (await withRetries(() =>
      fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(targetUid)}`, {
        headers: { Authorization: `Bearer ${apiKey}` },
      })
    )) as Response;

    if (resp.status === 404) {
      console.warn(`[RC Reconcile] No RC subscriber for ${targetUid}`);
      return { uid: targetUid, productId: null, tier: "none", status: "inactive", expiresAt: null, graceUntil: null, isInGrace: false };
    }

    const json: any = await resp.json();
    const subscriber = json?.subscriber ?? {};
    console.info("[RC Reconcile] Raw RC subscriber", { uid: targetUid, entitlements: subscriber.entitlements ?? {}, subscriptions: subscriber.subscriptions ?? {} });

    // ── Resolve entitlements ──────────────────────────
    const productId = resolveActiveProductIdFromSubscriber(subscriber);
    const activeSub = productId ? subscriber.subscriptions?.[productId] : null;
    const expiresAt = activeSub?.expires_date ?? null;
    const eventType = activeSub?.unsubscribe_detected_at ? "CANCELLATION" : null;

    const result = toResult(productId, { expiresAt, eventType, graceDays: 3 });
    const entitlementHash = computeEntitlementHash(result);

    const userRef = db.doc(`users/${targetUid}`);
    const snap = await userRef.get();
    const prevHash = snap.exists ? snap.get("entitlementHash") : undefined;

    const needsBackfill = !snap.exists || !snap.get("tier") || !snap.get("productId") || !snap.get("entitlementStatus");
    const changed = prevHash !== entitlementHash;
    const safeProductId = (result.productId ?? "none").toLowerCase();

    console.info("[RC Reconcile] Decision", { uid: targetUid, productId: result.productId, mappedTier: result.tier, entitlementStatus: result.entitlementStatus, prevHash, newHash: entitlementHash, changed, needsBackfill });

    if (changed || needsBackfill) {
      await withRetries(() =>
        userRef.set(
          {
            productId: safeProductId,
            tier: result.tier,
            entitlementStatus: result.entitlementStatus,
            expiresAt: result.expiresAt ? admin.firestore.Timestamp.fromDate(result.expiresAt) : null,
            graceUntil: result.graceUntil ? admin.firestore.Timestamp.fromDate(result.graceUntil) : null,
            isInGrace: !!(result.graceUntil && result.graceUntil > new Date()),
            entitlementHash,
            lastEntitlementEventAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        )
      );
      console.info(`[RC Reconcile] ✅ Firestore updated for ${targetUid} → ${result.tier}`);
    } else {
      console.info(`[RC Reconcile] ℹ️ No Firestore update for ${targetUid}`);
    }

    return { uid: targetUid, productId: result.productId, tier: result.tier, status: result.entitlementStatus, expiresAt: result.expiresAt, graceUntil: result.graceUntil, isInGrace: !!(result.graceUntil && result.graceUntil > new Date()) };
  }
);