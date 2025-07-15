import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { getUserEntitlementFromRevenueCat } from './revcat.js';

const firestore = getFirestore();

export const syncEntitlementTier = onCall({ region: 'europe-west2' }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'User not logged in.');

  const entitlement = await getUserEntitlementFromRevenueCat(uid);
  await firestore.collection('users').doc(uid).update({ tier: entitlement });

  return { success: true };
});