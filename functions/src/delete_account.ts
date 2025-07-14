import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

// Optional: Ensure Firebase is initialised (only needed if not already initialised elsewhere)
import "./firebase.js";

const firestore = getFirestore();
const auth = getAuth();
const storage = getStorage();

export const deleteAccount = onCall({ region: "europe-west2" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  // 🔒 Optional: ensure this is running on the correct project
  const expectedProjectId = "recipevault-bg-ai";
  const projectId = process.env.GCLOUD_PROJECT || process.env.FUNCTIONS_PROJECT_ID || "";
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

  try {
    // 🧹 Delete all subcollections
    try {
      const subcollections = await userDocRef.listCollections();
      for (const col of subcollections) {
        const snap = await col.get();
        const batch = firestore.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        console.log(`🧹 Deleted ${snap.size} docs from ${col.id}`);
      }
      result.subcollectionsDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting subcollections:", err);
      throw new HttpsError("internal", "Failed to delete subcollections.");
    }

    // 🗑️ Delete main user document
    try {
      await userDocRef.delete();
      console.log("✅ User document deleted.");
      result.firestoreDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting user document:", err);
      throw new HttpsError("internal", "Failed to delete user document.");
    }

    // 📁 Delete user storage files
    try {
      const bucketName = "recipevault-bg-ai.appspot.com";
      await storage.bucket(bucketName).deleteFiles({ prefix: `users/${uid}/` });
      console.log(`🗑️ Deleted storage files for user ${uid}`);
      result.storageDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting storage files:", err);
      throw new HttpsError("internal", "Failed to delete storage files.");
    }

    // 👤 Delete Firebase Auth user
    try {
      await auth.deleteUser(uid);
      console.log("👤 Firebase Auth user deleted.");
      result.authDeleted = true;
    } catch (err) {
      console.error("❌ Failed deleting Firebase Auth user:", err);
      throw new HttpsError("internal", "Failed to delete Firebase Auth user.");
    }

    console.log(`✅ Account deletion complete for UID: ${uid}`);
    return {
      success: true,
      ...result,
    };
  } catch (error: any) {
    console.error("❌ Account deletion failed:", error);
    throw new HttpsError("internal", error?.message || "Account deletion failed.");
  }
});