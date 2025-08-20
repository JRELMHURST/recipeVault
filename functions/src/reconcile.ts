// functions/src/reconcile_user_from_rc.ts
import admin, { firestore } from "./firebase.js";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";
import { resolveActiveProductIdFromSubscriber, computeEntitlementHash } from "./revenuecat.js";
import { toResult } from "./reconcile_entitlement.js";

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

    // Use built-in fetch if on Node 18+ (drop node-fetch). Keeping generic:
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(targetUid)}`,
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );
    if (!resp.ok) throw new HttpsError("internal", `RC fetch failed: ${resp.status} ${await resp.text()}`);

    const json: any = await resp.json();
    const subscriber = json?.subscriber ?? {};

    // 🔁 Centralised productId resolution
    const productId = resolveActiveProductIdFromSubscriber(subscriber);

    const r = toResult(productId);

    // Shared hash
    const entitlementHash =
      typeof computeEntitlementHash === "function"
        ? computeEntitlementHash(r)
        : crypto.createHash("sha256").update(JSON.stringify({ productId: r.productId ?? "none", tier: r.tier })).digest("hex");

    const userRef = db.doc(`users/${targetUid}`);
    const snap = await userRef.get();
    const prevHash = snap.exists ? snap.get("entitlementHash") : undefined;

    const changed = prevHash !== entitlementHash;
    if (changed) {
      await userRef.set(
        {
          productId: (r.productId ?? "none").toLowerCase(),
          tier: r.tier,
          entitlementStatus: r.entitlementStatus,
          graceUntil: r.graceUntil,
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

    return {
      uid: targetUid,
      productId: r.productId,
      tier: r.tier,
      status: r.entitlementStatus,
      effectiveUntil: r.graceUntil ?? null,
    };
  }
);