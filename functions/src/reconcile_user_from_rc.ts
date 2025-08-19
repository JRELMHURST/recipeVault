import admin, { firestore } from "./firebase.js";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import fetch from "node-fetch";
import { productToTier } from "./mapping.js";

const db = firestore;

/**
 * Callable to reconcile a user’s entitlement from RevenueCat REST API
 */
export const reconcileUserFromRC = onCall(async (request: CallableRequest) => {
  const uidParam = String(request.data?.uid ?? "");
  const callerUid = request.auth?.uid;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "You must be signed in");
  }

  let targetUid: string;

  if (request.auth?.token?.admin) {
    if (!uidParam) {
      throw new HttpsError("invalid-argument", "uid required for admin call");
    }
    targetUid = uidParam;
  } else {
    if (uidParam && uidParam !== callerUid) {
      throw new HttpsError("permission-denied", "Clients may only reconcile their own account");
    }
    targetUid = callerUid;
  }

  const apiKey = process.env.RC_API_KEY;
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "Missing RC API key in env");
  }

  const resp = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(targetUid)}`,
    { headers: { Authorization: `Bearer ${apiKey}` } }
  );

  if (!resp.ok) {
    const text = await resp.text();
    throw new HttpsError("internal", `RC fetch failed: ${resp.status} ${text}`);
  }

  const json: any = await resp.json();
  const subscriber = json?.subscriber ?? {};
  let productId: string | null = null;

  const ents = subscriber.entitlements ?? {};
  for (const key of Object.keys(ents)) {
    const ent = ents[key];
    if (ent?.is_active && ent?.product_identifier) {
      productId = String(ent.product_identifier);
      break;
    }
  }

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

  await db.doc(`users/${targetUid}`).set(
    {
      productId: (productId ?? "none").toLowerCase(),
      tier,
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { uid: targetUid, productId, tier };
});