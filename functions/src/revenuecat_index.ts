import admin, { firestore } from "./firebase.js";
import {
  onRequest,
  onCall,
  CallableRequest,
  HttpsError,
} from "firebase-functions/v2/https";
import fetch from "node-fetch";

import { resolveTierFromPayload } from "./revenuecat.js";
import { productToTier } from "./mapping.js";
import { verifyRevenueCatSignature } from "./rc-verify.js";

// Firestore instance
const db = firestore;

/**
 * 1) RevenueCat webhook → server-owned write of {tier, productId}
 * This is the ONLY place where user entitlements are set.
 */
export const revenuecatWebhook = onRequest(async (req, res) => {
  try {
    const secret = process.env.RC_WEBHOOK_SECRET;
    if (!secret) {
      console.error("Missing RC webhook secret in env");
      res.status(500).send("Missing RC secret");
      return;
    }

    // Verify signature
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

    // Always upsert the Firestore doc
    await db.doc(`users/${uid}`).set(
      {
        productId: productId?.toLowerCase() ?? "none",
        tier: tier ?? "none",
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.info(
      `RC webhook upsert → uid=${uid}, productId=${productId}, tier=${tier}`
    );
    res.status(200).send("ok");
  } catch (e: any) {
    console.error("RC webhook error", e);
    res.status(500).send("error");
  }
});

/**
 * 2) Admin-only callable to reconcile a user on-demand from RevenueCat REST
 */
export const reconcileUserFromRC = onCall(
  async (request: CallableRequest) => {
    if (!request.auth?.token?.admin) {
      throw new HttpsError("permission-denied", "unauthorized");
    }

    const uid = String(request.data?.uid ?? "");
    if (!uid) throw new HttpsError("invalid-argument", "uid required");

    const apiKey = process.env.RC_API_KEY;
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "Missing RC API key in env");
    }

    // Fetch from RevenueCat REST
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      {
        headers: { Authorization: `Bearer ${apiKey}` },
      }
    );

    if (!resp.ok) {
      const text = await resp.text();
      throw new HttpsError(
        "internal",
        `RC fetch failed: ${resp.status} ${text}`
      );
    }

    const json: any = await resp.json();
    const subscriber = json?.subscriber ?? {};

    let productId: string | null = null;

    // Try entitlements first
    const ents = subscriber.entitlements ?? {};
    for (const key of Object.keys(ents)) {
      const ent = ents[key];
      if (ent?.is_active && ent?.product_identifier) {
        productId = String(ent.product_identifier);
        break;
      }
    }

    // Fallback to active subscription name
    if (!productId) {
      const subs = subscriber.subscriptions ?? {};
      for (const pid of Object.keys(subs)) {
        const s = subs[pid];
        const expires = s?.expires_date ? new Date(s.expires_date) : null;
        if (!expires || expires > new Date()) {
          productId = pid;
          break;
        }
      }
    }

    const tier = productToTier(productId);

    // Upsert into Firestore
    await db.doc(`users/${uid}`).set(
      {
        productId: (productId ?? "none").toLowerCase(),
        tier,
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { uid, productId, tier };
  }
);