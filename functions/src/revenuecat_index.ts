// functions/src/revenuecat_index.ts
import admin from "firebase-admin";
import {
  beforeUserCreated,
} from "firebase-functions/v2/identity";
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

admin.initializeApp();
const db = admin.firestore();

/**
 * 1) Create user doc on sign-up (v2 blocking identity trigger)
 */
export const onAuthInitUser = beforeUserCreated(async (event) => {
  const user = event.data;
  if (!user) return;

  const uid = user.uid;
  const email = user.email ?? null;

  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (snap.exists) return;

  await ref.set({
    email,
    productId: "none",
    tier: "none",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastLogin: admin.firestore.FieldValue.serverTimestamp(),
    platform: null,
    usage: {},
  });
});

/**
 * 2) RevenueCat webhook → server-owned write of {tier, productId}
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

    await db.doc(`users/${uid}`).set(
      {
        productId: productId?.toLowerCase() ?? "none",
        tier,
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
 * 3) Admin-only callable to reconcile a user on-demand from RevenueCat REST
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

    // RevenueCat REST v1
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