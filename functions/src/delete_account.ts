// src/delete_account.ts or similar
import "./firebase";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const firestore = getFirestore();

export const deleteAccount = onCall({ region: "europe-west2" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  await firestore.doc(`users/${uid}`).set(
    { markedForDeletionAt: Date.now() },
    { merge: true }
  );

  return { success: true };
});