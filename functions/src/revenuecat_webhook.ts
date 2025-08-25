import { firestore, Timestamp, FieldValue } from "./firebase.js";
import { onRequest } from "firebase-functions/v2/https";
import { resolveTierFromPayload, computeEntitlementHash } from "./revenuecat.js";
import { verifyRevenueCatSignature } from "./rc-verify.js";
import * as crypto from "crypto";
import { toResult } from "./reconcile_entitlement.js";
import type { Tier } from "./types.js";

const db = firestore;

export const revenuecatWebhook = onRequest(
  { region: "europe-west2" },
  async (req, res): Promise<void> => {
    try {
      const secret = process.env.RC_WEBHOOK_SECRET;
      if (!secret) {
        res.status(500).send("Missing RC secret");
        return;
      }

      const sig = req.get("X-Webhook-Signature");
      if (!sig) {
        res.status(401).send("unauthorized");
        return;
      }

      if (!req.is("application/json")) {
        res.status(415).send("unsupported media type");
        return;
      }

      if (!verifyRevenueCatSignature(req.rawBody, sig, secret)) {
        console.warn("❌ Invalid RC signature");
        res.status(401).send("unauthorized");
        return;
      }

      const payload = req.body;

      // 1) Fast-path for RC test/ping or unknown events
      const eventType: string | undefined = payload?.event?.type;
      if (!eventType) {
        console.info("ℹ️ RC webhook: no event.type, ack");
        res.status(200).send("ok");
        return;
      }

      const interesting = [
        "INITIAL_PURCHASE",
        "NON_RENEWING_PURCHASE",
        "PRODUCT_CHANGE",
        "CANCELLATION",
        "UNCANCELLATION",
        "BILLING_ISSUE",
        "RENEWAL",
        "SUBSCRIPTION_PAUSED",
        "SUBSCRIPTION_RESUMED",
        "EXPIRATION",
        "TRANSFER",
      ];
      if (!interesting.includes(eventType)) {
        console.info(`ℹ️ RC webhook: ignoring event ${eventType}`);
        res.status(200).send("ok");
        return;
      }

      const { uid, productId } = resolveTierFromPayload(payload);
      if (!uid) {
        console.warn("⚠️ RC payload without app_user_id; skipping");
        res.status(200).send("ok");
        return;
      }

      // Always log incoming before dedupe
      console.info("[RC Webhook] Incoming", {
        eventType,
        uid,
        productId,
      });

      // 2) Idempotency check
      const eventId =
        payload?.event?.id ||
        crypto.createHash("sha256").update(req.rawBody).digest("hex");

      const dedupeRef = db.doc(`rc_events/${eventId}`);
      try {
        await dedupeRef.create({ uid, at: FieldValue.serverTimestamp() });
      } catch {
        console.info(`[RC Webhook] Duplicate event ${eventId}, ack`);
        res.status(200).send("ok");
        return;
      }

      // 3) Normalise entitlement using reconcile logic
      const expiresAt = payload?.event?.expiration_at
        ? new Date(payload.event.expiration_at)
        : null;

      const r = toResult(productId, {
        expiresAt,
        eventType,
        graceDays: 3,
      });

      const normalizedStatus: "active" | "inactive" =
        r.entitlementStatus === "active" ? "active" : "inactive";

      const normalized = {
        productId: (r.productId ?? "none").toLowerCase(),
        tier: r.tier as Tier,
        entitlementStatus: normalizedStatus,
        graceUntil: r.graceUntil,
      };

      // 4) Compute hash
      const entitlementHash = computeEntitlementHash({
        productId: normalized.productId,
        tier: normalized.tier,
        entitlementStatus: normalized.entitlementStatus,
        graceUntil: normalized.graceUntil,
      });

      const userRef = db.doc(`users/${uid}`);
      const userSnap = await userRef.get();
      const prevHash: string | undefined = userSnap.exists
        ? (userSnap.get("entitlementHash") as string | undefined)
        : undefined;

      const changed = prevHash !== entitlementHash;
      const needsBackfill =
        !userSnap.exists ||
        !userSnap.get("tier") ||
        !userSnap.get("productId") ||
        !userSnap.get("entitlementStatus");

      // 5) Per-user audit trail
      const auditRef = db.doc(`users/${uid}/rcEvents/${eventId}`);

      const eventAt = payload?.event?.occurred_at
        ? Timestamp.fromDate(new Date(payload.event.occurred_at))
        : FieldValue.serverTimestamp();

      if (changed || needsBackfill) {
        await userRef.set(
          {
            productId: normalized.productId,
            tier: normalized.tier,
            entitlementStatus: normalized.entitlementStatus,
            expiresAt: r.expiresAt ? Timestamp.fromDate(r.expiresAt) : null,
            graceUntil: normalized.graceUntil
              ? Timestamp.fromDate(normalized.graceUntil)
              : null,
            isInGrace:
              !!(normalized.graceUntil &&
              normalized.graceUntil > new Date()),
            entitlementHash,
            lastEntitlementEventAt: eventAt,
          },
          { merge: true }
        );
        console.info(`[RC Webhook] ✅ Firestore updated for ${uid} → ${normalized.tier}`);
      } else {
        console.info(`[RC Webhook] ℹ️ No Firestore update for ${uid}`);
      }

      await auditRef.set(
        {
          eventId,
          type: eventType,
          productId: normalized.productId,
          tier: normalized.tier,
          entitlementStatus: normalized.entitlementStatus,
          expiresAt: r.expiresAt ? Timestamp.fromDate(r.expiresAt) : null,
          graceUntil: normalized.graceUntil
            ? Timestamp.fromDate(normalized.graceUntil)
            : null,
          at: eventAt,
          changed,
          prevHash,
          newHash: entitlementHash,
        },
        { merge: true }
      );

      res.status(200).send("ok");
    } catch (e) {
      console.error("RC webhook error", e);
      res.status(500).send("error");
    }
  }
);