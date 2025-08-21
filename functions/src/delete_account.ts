// functions/src/delete_account.ts
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
  { enforceAppCheck: false }, // ✅ flip to true if your clients support App Check
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const projectId =
      process.env.GCLOUD_PROJECT || process.env.FUNCTIONS_PROJECT_ID || "";
    if (!projectId) {
      throw new HttpsError(
        "failed-precondition",
        "No project environment detected."
      );
    }

    const userDocRef = firestore.collection("users").doc(uid);
    const result = {
      firestoreDeleted: false,
      subcollectionsDeleted: false,
      storageDeleted: false,
      authDeleted: false,
      details: {
        recipesDeleted: 0,
        categoriesDeleted: 0,
        aiUsageDeleted: 0,
        translatedRecipeUsageDeleted: 0,
        imageUsageDeleted: 0,
        prefsDeleted: 0,
        translationsDeleted: 0,
      },
    };

    console.log(`🔥 Starting full account deletion for UID: ${uid}`);

    // 🔄 Delete subcollections
    try {
      result.details.recipesDeleted = await deleteSubcollectionBatching(userDocRef, "recipes");
      result.details.categoriesDeleted = await deleteSubcollectionBatching(userDocRef, "categories");
      result.details.aiUsageDeleted = await deleteSubcollectionBatching(userDocRef, "aiUsage");
      result.details.translatedRecipeUsageDeleted = await deleteSubcollectionBatching(userDocRef, "translatedRecipeUsage");
      result.details.imageUsageDeleted = await deleteSubcollectionBatching(userDocRef, "imageUsage");
      result.details.prefsDeleted = await deleteSubcollectionBatching(userDocRef, "prefs");
      result.details.translationsDeleted = await deleteSubcollectionBatching(userDocRef, "translations");

      result.subcollectionsDeleted = true;
      console.log("🧹 Subcollections deleted:", result.details);
    } catch (err) {
      console.error("❌ Failed deleting subcollections:", err);
    }

    // 🧾 Delete user doc
    try {
      await userDocRef.delete();
      result.firestoreDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting user document:", err);
    }

    // 🗃️ Delete user storage (default bucket unless multi-bucket setup)
    try {
      const bucket = storage.bucket(); // ✅ safer: uses default bucket
      await bucket.deleteFiles({ prefix: `users/${uid}/` });
      result.storageDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting storage files:", err);
    }

    // 🔐 Delete Firebase Auth user LAST
    try {
      await auth.deleteUser(uid);
      result.authDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting Firebase Auth user:", err);
    }

    console.log(`✅ Account deletion complete for UID: ${uid}`, result);
    return { success: true, ...result };
  }
);