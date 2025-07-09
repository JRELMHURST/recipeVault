import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";
import { initializeApp } from "firebase-admin/app";

initializeApp();

const firestore = getFirestore();

/**
 * Marks the user's account for deletion in 30 days.
 * A scheduled function (see cleanup script) will handle actual deletion.
 */
export const deleteAccount = onCall({ region: "europe-west2" }, async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to delete account."
    );
  }

  try {
    const userRef = firestore.doc(`users/${uid}`);
    await userRef.set(
      { markedForDeletionAt: Date.now() },
      { merge: true }
    );

    return { success: true, message: "Account marked for deletion in 30 days." };
  } catch (err: any) {
    console.error("Failed to mark account for deletion:", err);
    throw new functions.https.HttpsError("internal", "Failed to mark account for deletion.");
  }
});