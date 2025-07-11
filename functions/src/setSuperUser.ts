import { onCall } from 'firebase-functions/v2/https';
import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import './firebase.js';

const firestore = getFirestore();

export const setSuperUser = onCall(
  { region: 'europe-west2' }, // ✅ Match client-side region
  async (request) => {
    const email: string | undefined = request.data?.email;

    if (!email || typeof email !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        "The function must be called with a valid 'email' field."
      );
    }

    const usersRef = firestore.collection('users');
    const snapshot = await usersRef.where('email', '==', email).get();

    if (snapshot.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        `No user document found for email: ${email}`
      );
    }

    const userDoc = snapshot.docs[0];
    await userDoc.ref.update({ superUser: true });

    return {
      success: true,
      message: `User ${email} marked as superUser.`,
    };
  }
);