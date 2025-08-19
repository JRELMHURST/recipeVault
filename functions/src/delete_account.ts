import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import "./firebase.js";

const firestore = getFirestore();
const auth = getAuth();
const storage = getStorage();

export const deleteAccount = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const expectedProjectId = "recipevault-bg-ai";
    const projectId =
      process.env.GCLOUD_PROJECT || process.env.FUNCTIONS_PROJECT_ID || "";
    if (projectId !== expectedProjectId) {
      throw new HttpsError("permission-denied", "Invalid project environment.");
    }

    const userDocRef = firestore.collection("users").doc(uid);
    const result = {
      firestoreDeleted: false,
      subcollectionsDeleted: false,
      storageDeleted: false,
      authDeleted: false,
    };

    console.log(`🔥 Starting full account deletion for UID: ${uid}`);

    // 🔄 Delete subcollections
    try {
      const subcollections = [
        "recipes",
        "categories",
        "aiUsage",
        "translationUsage",
        "imageUsage",
      ];

      for (const colId of subcollections) {
        const colRef = userDocRef.collection(colId);
        const snap = await colRef.get();
        if (snap.empty) continue;

        // Batch in chunks of 500
        while (!snap.empty) {
          const batch = firestore.batch();
          snap.docs.slice(0, 500).forEach((doc) => batch.delete(doc.ref));
          await batch.commit();
        }
        console.log(`🧹 Deleted ${snap.size} docs from ${colId}`);
      }
      result.subcollectionsDeleted = true;
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

    // 🗃️ Delete user storage
    try {
      const bucket = storage.bucket('recipevault-bg-ai.firebasestorage.app');
      await bucket.deleteFiles({ prefix: `users/${uid}/` });
      result.storageDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting storage files:", err);
    }

    // 🔐 Delete Firebase Auth user
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