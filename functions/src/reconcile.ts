import admin, { firestore } from "./firebase.js";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import fetch from "node-fetch";
import * as crypto from "crypto";
import { toResult } from "./reconcile_entitlement.js";   // ⬅️ NEW
// (kept) productToTier is now used inside toResult()

const db = firestore;

export const reconcileUserFromRC = onCall(
  { region: "europe-west2", enforceAppCheck: true },
  async (request: CallableRequest) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in");
    }

    const uidParam = String(request.data?.uid ?? "");
    const callerUid = request.auth.uid;

    const targetUid =
      request.auth.token?.admin
        ? (uidParam || (() => { throw new HttpsError("invalid-argument", "uid required for admin call"); })())
        : (uidParam && uidParam !== callerUid
            ? (() => { throw new HttpsError("permission-denied", "Clients may only reconcile their own account"); })()
            : callerUid);

    const apiKey = process.env.RC_API_KEY;
    if (!apiKey) throw new HttpsError("failed-precondition", "Missing RC API key");

    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(targetUid)}`,
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );
    if (!resp.ok) throw new HttpsError("internal", `RC fetch failed: ${resp.status} ${await resp.text()}`);

    const json: any = await resp.json();
    const subscriber = json?.subscriber ?? {};

    // Resolve active productId from entitlements first, then subscriptions/expiry
    let productId: string | null = null;
    const ents = subscriber.entitlements ?? {};
    for (const ent of Object.values(ents)) {
      if ((ent as any)?.is_active && (ent as any)?.product_identifier) {
        productId = String((ent as any).product_identifier);
        break;
      }
    }
    if (!productId) {
      const subs = subscriber.subscriptions ?? {};
      for (const [pid, s] of Object.entries<any>(subs)) {
        const expires = s?.expires_date ? new Date(s.expires_date) : null;
        if (!expires || expires > new Date()) { productId = pid; break; }
      }
    }

    // ⬇️ Single source of truth for tier/status/grace
    const r = toResult(productId);

    // No‑op write guard
    const entitlementHash = crypto
      .createHash("sha256")
      .update(JSON.stringify({ productId: r.productId ?? "none", tier: r.tier }))
      .digest("hex");

    const userRef = db.doc(`users/${targetUid}`);
    const snap = await userRef.get();
    const prevHash = snap.exists ? snap.get("entitlementHash") : undefined;

    const changed = prevHash !== entitlementHash;
    if (changed) {
      await userRef.set(
        {
          productId: (r.productId ?? "none").toLowerCase(),
          tier: r.tier,
          entitlementStatus: r.entitlementStatus,   // ⬅️ NEW
          graceUntil: r.graceUntil,                 // ⬅️ NEW (null for now)
          entitlementHash,
          lastLogin: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    console.info({
      msg: "reconcileUserFromRC",
      source: "callable",
      uid: targetUid,
      productId: r.productId,
      tier: r.tier,
      entitlementStatus: r.entitlementStatus,
      changed,
    });

    // Optionally extend the return for cleaner client UX
    return {
      uid: targetUid,
      productId: r.productId,
      tier: r.tier,
      status: r.entitlementStatus,
      effectiveUntil: r.graceUntil ?? null,
    };
  }
);