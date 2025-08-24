import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
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
  while (true) {
    const snap = await userDocRef.collection(colId).limit(500).get();
    if (snap.empty) break;

    const batch = firestore.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
  }
  return deleted;
}

export const deleteAccount = onCall(
  { enforceAppCheck: false }, // 🔒 flip true in prod
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "User must be authenticated.");

    const userDocRef = firestore.collection("users").doc(uid);
    const result = {
      firestoreDeleted: false,
      subcollectionsDeleted: false,
      storageDeleted: false,
      authDeleted: false,
      details: {},
    } as any;

    console.log(`🔥 Deleting account for UID=${uid}`);

    try {
      // subcollections
      for (const col of [
        "recipes",
        "categories",
        "recipeUsage",
        "translationUsage",
        "imageUsage",
        "prefs",
      ]) {
        const count = await deleteSubcollectionBatching(userDocRef, col);
        result.details[col] = count;
      }
      result.subcollectionsDeleted = true;

      // doc
      await userDocRef.delete();
      result.firestoreDeleted = true;

      // storage
      await storage.bucket().deleteFiles({ prefix: `users/${uid}/` });
      result.storageDeleted = true;

      // auth user
      await auth.deleteUser(uid);
      result.authDeleted = true;

      console.log(`✅ Account deletion complete for ${uid}`);
    } catch (err) {
      console.error(`❌ Account deletion error for ${uid}`, err);
    }

    return { success: true, ...result };
  }
);