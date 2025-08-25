// functions/src/deleteAccount.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import "./firebase.js";

const firestore = getFirestore();
const auth = getAuth();
const storage = getStorage();

async function deleteSubcollectionBatching(
  userDocRef: FirebaseFirestore.DocumentReference,
  colId: string
): Promise<number> {
  let deleted = 0;
  // Loop batches until the subcollection is empty
  // (limits to 500 per batch to stay within API constraints)
  for (;;) {
    const snap = await userDocRef.collection(colId).limit(500).get();
    if (snap.empty) break;

    const batch = firestore.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
  }
  return deleted;
}

/**
 * 🔥 Deletes *everything* for the current user:
 * - Firestore: subcollections + user doc
 * - Storage: users/{uid}/*
 * - Auth: user account
 */
export const deleteAccount = onCall(
  {
    // ✅ flip to true in production after App Check is enabled in the app
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const userDocRef = firestore.collection("users").doc(uid);

    const result: {
      firestoreDeleted: boolean;
      subcollectionsDeleted: boolean;
      storageDeleted: boolean;
      authDeleted: boolean;
      details: Record<string, number>;
    } = {
      firestoreDeleted: false,
      subcollectionsDeleted: false,
      storageDeleted: false,
      authDeleted: false,
      details: {},
    };

    console.log(`🔥 Deleting account for UID=${uid}`);

    // 1) Subcollections (counted)
    try {
      for (const col of [
        "recipes",
        "categories",
        "recipeUsage",
        "translatedRecipeUsage", // ✅ correct name
        "imageUsage",
        "prefs",
      ]) {
        const count = await deleteSubcollectionBatching(userDocRef, col);
        result.details[col] = count;
      }
      result.subcollectionsDeleted = true;
    } catch (err) {
      console.error(`❌ Failed deleting subcollections for ${uid}`, err);
    }

    // 2) Delete main user doc
    try {
      await userDocRef.delete();
      result.firestoreDeleted = true;
    } catch (err) {
      console.error(`❌ Failed deleting user doc for ${uid}`, err);
    }

    // 3) Storage: delete all user files
    try {
      await storage.bucket().deleteFiles({ prefix: `users/${uid}/` });
      result.storageDeleted = true;
    } catch (err) {
      console.error(`❌ Failed deleting storage for ${uid}`, err);
    }

    // 4) Auth: delete the account
    try {
      // Optional: mark a tombstone first (useful for analytics/audits)
      try {
        await firestore.collection("deletedUsers").doc(uid).set({
          uid,
          deletedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      } catch (_) {
        /* non-fatal */
      }

      await auth.deleteUser(uid);
      result.authDeleted = true;
    } catch (err) {
      console.error(`❌ Failed deleting auth user for ${uid}`, err);
    }

    console.log(`✅ Account deletion complete for ${uid}`, result);
    return { success: true, ...result };
  }
);