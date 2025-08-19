import admin, { firestore } from "./firebase.js";
import { onRequest } from "firebase-functions/v2/https";
import { resolveTierFromPayload } from "./revenuecat.js";
import { verifyRevenueCatSignature } from "./rc-verify.js";
import * as crypto from "crypto";
import { toResult } from "./reconcile_entitlement.js";   // ⬅️ NEW

const db = firestore;

export const revenuecatWebhook = onRequest({ region: "europe-west2" }, async (req, res) => {
  try {
    const secret = process.env.RC_WEBHOOK_SECRET;
    if (!secret) { res.status(500).send("Missing RC secret"); return; }

    const sig = req.get("X-Webhook-Signature");
    if (!sig) { res.status(401).send("unauthorized"); return; }

    if (!req.is("application/json")) { res.status(415).send("unsupported media type"); return; }

    // Verify signature against RAW body
    if (!verifyRevenueCatSignature(req.rawBody, sig, secret)) {
      console.warn("Invalid RC signature");
      res.status(401).send("unauthorized");
      return;
    }

    const payload = req.body;

    // We only need uid + productId; tier will come from toResult()
    const { uid, productId } = resolveTierFromPayload(payload);
    if (!uid) {
      console.warn("RC payload without app_user_id; skipping");
      res.status(200).send("ok");
      return;
    }

    // Idempotency: RC event id or hash of raw body
    const eventId = payload?.event?.id || crypto.createHash("sha256").update(req.rawBody).digest("hex");
    const dedupeRef = db.doc(`rc_events/${eventId}`);
    const dedupeSnap = await dedupeRef.get();
    if (dedupeSnap.exists) {
      console.info({ msg: "RC duplicate event ignored", eventId });
      res.status(200).send("ok");
      return;
    }

    // ⬇️ Single source of truth for tier/status/grace
    const r = toResult(productId);

    // No‑op write guard
    const entitlementHash = crypto
      .createHash("sha256")
      .update(JSON.stringify({ productId: r.productId ?? "none", tier: r.tier }))
      .digest("hex");

    const userRef = db.doc(`users/${uid}`);
    const userSnap = await userRef.get();
    const prevHash = userSnap.exists ? userSnap.get("entitlementHash") : undefined;

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

    // Mark event processed
    await dedupeRef.create({
      uid,
      at: admin.firestore.FieldValue.serverTimestamp(),
    });

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

    res.status(200).send("ok");
  } catch (e) {
    console.error("RC webhook error", e);
    res.status(500).send("error");
  }
});