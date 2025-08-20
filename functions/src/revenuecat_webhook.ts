// functions/src/revenuecat_webhook.ts
import admin, { firestore } from "./firebase.js";
import { onRequest } from "firebase-functions/v2/https";
import { resolveTierFromPayload, computeEntitlementHash } from "./revenuecat.js";
import { verifyRevenueCatSignature } from "./rc-verify.js";
import * as crypto from "crypto";
import { toResult } from "./reconcile_entitlement.js";

const db = firestore;

export const revenuecatWebhook = onRequest({ region: "europe-west2" }, async (req, res): Promise<void> => {
  try {
    const secret = process.env.RC_WEBHOOK_SECRET;
    if (!secret) { res.status(500).send("Missing RC secret"); return; }

    const sig = req.get("X-Webhook-Signature");
    if (!sig) { res.status(401).send("unauthorized"); return; }

    if (!req.is("application/json")) { res.status(415).send("unsupported media type"); return; }

    if (!verifyRevenueCatSignature(req.rawBody, sig, secret)) {
      console.warn("Invalid RC signature");
      res.status(401).send("unauthorized");
      return; // ✅ do not return the Response
    }

    const payload = req.body;
    const { uid, productId } = resolveTierFromPayload(payload);
    if (!uid) {
      console.warn("RC payload without app_user_id; skipping");
      res.status(200).send("ok");
      return; // ✅
    }

    // Idempotency
    const eventId = payload?.event?.id || crypto.createHash("sha256").update(req.rawBody).digest("hex");
    const dedupeRef = db.doc(`rc_events/${eventId}`);
    try {
      await dedupeRef.create({ uid, at: admin.firestore.FieldValue.serverTimestamp() });
    } catch (e: any) {
      // Already processed
      res.status(200).send("ok");
      return; // ✅
    }

    const r = toResult(productId);

    const entitlementHash = computeEntitlementHash({
      productId: r.productId,
      tier: r.tier,
      entitlementStatus: r.entitlementStatus,
      graceUntil: r.graceUntil,
    });

    const userRef = db.doc(`users/${uid}`);
    const userSnap = await userRef.get();
    const prevHash = userSnap.exists ? userSnap.get("entitlementHash") : undefined;

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
      msg: "revenuecatWebhook reconciled",
      source: "webhook",
      eventId,
      uid,
      productId: r.productId,
      tier: r.tier,
      entitlementStatus: r.entitlementStatus,
      changed,
    });

    res.status(200).send("ok"); // ✅ send response
    return;                      // ✅ but don't return the Response
  } catch (e) {
    console.error("RC webhook error", e);
    res.status(500).send("error"); // ✅ send response
    return;                        // ✅ end the Promise<void>
  }
});