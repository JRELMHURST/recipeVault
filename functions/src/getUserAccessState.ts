import { onCall } from 'firebase-functions/v2/https';
import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import { SubscriptionService } from './_shared/subscription_service.js';
import './firebase.js';

export const getUserAccessState = onCall({ region: 'europe-west2' }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  }

  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.data();

  const isSuperUser = userData?.superUser === true;
  if (isSuperUser) {
    return { route: '/home' }; // ✅ Super users go straight to home
  }

  const hasSeenWelcome = userData?.hasSeenWelcome === true;
  const subscriptionTier = userData?.subscriptionTier ?? 'taster';

  const isPaid = SubscriptionService.isPaid(subscriptionTier);
  const isTrialActive = SubscriptionService.isTrialActive(userData);

  if (!isPaid && !isTrialActive) return { route: '/pricing' };
  if (!hasSeenWelcome) return { route: '/welcome' };

  return { route: '/home' };
});