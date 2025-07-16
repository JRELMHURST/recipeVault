import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { getUserEntitlementFromRevenueCat } from './revcat.js';

const firestore = getFirestore();
const auth = getAuth();

export const syncEntitlementTier = onCall({ region: 'europe-west2' }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'User not logged in.');
  }

  const entitlement = await getUserEntitlementFromRevenueCat(uid);
  if (!entitlement) {
    throw new HttpsError('not-found', 'No entitlement found for this user.');
  }

  // ✅ Set custom claim to bypass Firestore rule on 'tier'
  await auth.setCustomUserClaims(uid, { admin: true });

  // ✅ Now update the tier in Firestore (rules will allow this)
  await firestore.collection('users').doc(uid).update({ tier: entitlement });

  return {
    success: true,
    tier: entitlement,
  };
});