// functions/src/_shared/getUserAccessState.ts

import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";
import { SubscriptionService } from "./subscription_service.js";

export const getUserAccessState = onCall({ region: "europe-west2" }, async (req) => {
  const uid = req.auth?.uid;

  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  const db = getFirestore();
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data();

  const hasSeenWelcome = userData?.hasSeenWelcome === true;
  const subscriptionTier = userData?.subscriptionTier ?? "taster";

  const isPaid = SubscriptionService.isPaid(subscriptionTier);
  const isTrialActive = SubscriptionService.isTrialActive(userData);

  // 🔒 No access → show paywall
  if (!isPaid && !isTrialActive) {
    return { route: "/pricing" };
  }

  // 🆓 Free access but has not completed intro
  if (!hasSeenWelcome) {
    return { route: "/welcome" };
  }

  // ✅ All conditions met
  return { route: "/home" };
});
