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
      return;
    }

    const payload = req.body;

    // 1) Fast-path for RC test/ping or unknown events
    const eventType: string | undefined = payload?.event?.type;
    if (!eventType) {
      console.info("RC webhook: no event.type, ack");
      res.status(200).send("ok");
      return;
    }

    const interesting = [
      "INITIAL_PURCHASE", "NON_RENEWING_PURCHASE", "PRODUCT_CHANGE",
      "CANCELLATION", "UNCANCELLATION", "BILLING_ISSUE", "RENEWAL",
      "SUBSCRIPTION_PAUSED", "SUBSCRIPTION_RESUMED", "EXPIRATION",
      "TRANSFER"
    ];
    if (!interesting.includes(eventType)) {
      console.info(`RC webhook: ignoring event ${eventType}`);
      res.status(200).send("ok");
      return;
    }

    const { uid, productId } = resolveTierFromPayload(payload);
    if (!uid) {
      console.warn("RC payload without app_user_id; skipping");
      res.status(200).send("ok");
      return;
    }

    // 2) Idempotency
    const eventId =
      payload?.event?.id ||
      crypto.createHash("sha256").update(req.rawBody).digest("hex");

    const dedupeRef = db.doc(`rc_events/${eventId}`);
    try {
      await dedupeRef.create({ uid, at: admin.firestore.FieldValue.serverTimestamp() });
    } catch {
      res.status(200).send("ok"); // already processed
      return;
    }

    // 3) Normalise entitlement using full reconcile logic
    const r = toResult(productId, {
      expiresAt: payload?.event?.expiration_at ?? null,
      eventType: eventType,
      graceDays: 3, // optional: adjust if you want grace handling
    });

    const normalized = {
      productId: (r.productId ?? "none").toLowerCase(),
      tier: r.tier,
      entitlementStatus: r.entitlementStatus,
      graceUntil: r.graceUntil,
    };

    // 4) Compute hash
    const entitlementHash = computeEntitlementHash(normalized);

    const userRef = db.doc(`users/${uid}`);
    const userSnap = await userRef.get();
    const prevHash = userSnap.exists ? userSnap.get("entitlementHash") : undefined;
    const changed = prevHash !== entitlementHash;

    // 5) Per-user audit trail
    const auditRef = db.doc(`users/${uid}/rcEvents/${eventId}`);

    const eventAt =
      payload?.event?.occurred_at
        ? admin.firestore.Timestamp.fromDate(new Date(payload.event.occurred_at))
        : admin.firestore.FieldValue.serverTimestamp();

    if (changed) {
      await userRef.set(
        {
          productId: normalized.productId,
          tier: normalized.tier,
          entitlementStatus: normalized.entitlementStatus,
          graceUntil: normalized.graceUntil,
          entitlementHash,
          lastEntitlementEventAt: eventAt,
        },
        { merge: true }
      );
    }

    await auditRef.set(
      {
        eventId,
        type: eventType,
        productId: normalized.productId,
        tier: normalized.tier,
        entitlementStatus: normalized.entitlementStatus,
        graceUntil: normalized.graceUntil,
        at: eventAt,
        changed,
      },
      { merge: true }
    );

    console.info({
      msg: "revenuecatWebhook reconciled",
      source: "webhook",
      eventId,
      uid,
      productId: normalized.productId,
      tier: normalized.tier,
      entitlementStatus: normalized.entitlementStatus,
      changed,
    });

    res.status(200).send("ok");
  } catch (e) {
    console.error("RC webhook error", e);
    res.status(500).send("error");
  }
});