import admin, { firestore } from "./firebase.js";
import { onRequest } from "firebase-functions/v2/https";
import { resolveTierFromPayload } from "./revenuecat.js";
import { verifyRevenueCatSignature } from "./rc-verify.js";

const db = firestore;

/**
 * RevenueCat webhook → server-owned write of {tier, productId}
 */
export const revenuecatWebhook = onRequest(async (req, res) => {
  try {
    const secret = process.env.RC_WEBHOOK_SECRET;
    if (!secret) {
      console.error("Missing RC webhook secret in env");
      res.status(500).send("Missing RC secret");
      return;
    }

    const ok = verifyRevenueCatSignature(
      req.rawBody,
      req.get("X-Webhook-Signature"),
      secret
    );
    if (!ok) {
      console.warn("Invalid RC signature");
      res.status(401).send("unauthorized");
      return;
    }

    const payload = req.body;
    const { uid, productId, tier } = resolveTierFromPayload(payload);

    if (!uid) {
      console.warn("RC payload without app_user_id; skipping");
      res.status(200).send("ok");
      return;
    }

    await db.doc(`users/${uid}`).set(
      {
        productId: productId?.toLowerCase() ?? "none",
        tier: tier ?? "none",
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.info(`RC webhook → uid=${uid}, productId=${productId}, tier=${tier}`);
    res.status(200).send("ok");
  } catch (e: any) {
    console.error("RC webhook error", e);
    res.status(500).send("error");
  }
});