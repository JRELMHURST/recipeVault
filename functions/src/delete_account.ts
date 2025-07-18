import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import "./firebase.js"; // ✅ Ensures Firebase is initialised

const firestore = getFirestore();
const auth = getAuth();
const storage = getStorage();

export const deleteAccount = onCall(
  {
    region: "europe-west2",
    enforceAppCheck: false, // ✅ Currently disabled, adjust if needed later
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      console.error("❌ No user authenticated in request.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const expectedProjectId = "recipevault-bg-ai";
    const projectId = process.env.GCLOUD_PROJECT || process.env.FUNCTIONS_PROJECT_ID || "";
    if (projectId !== expectedProjectId) {
      console.error(`❌ Mismatched project ID: got ${projectId}, expected ${expectedProjectId}`);
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
      // 🔄 Delete user subcollections
      try {
        const subcollections = ["recipes", "categories", "aiUsage", "translationUsage"];
        for (const colId of subcollections) {
          console.log(`📂 Checking subcollection: ${colId}`);
          const colRef = userDocRef.collection(colId);
          const snap = await colRef.get();

          if (snap.empty) {
            console.log(`— No docs found in users/${uid}/${colId}`);
            continue;
          }

          const batch = firestore.batch();
          snap.docs.forEach((doc) => {
            console.log(`— Queuing delete: ${colId}/${doc.id}`);
            batch.delete(doc.ref);
          });

          await batch.commit();
          console.log(`🧹 Deleted ${snap.size} docs from users/${uid}/${colId}`);
        }
        result.subcollectionsDeleted = true;
      } catch (err) {
        console.error("❌ Failed deleting subcollections:", err);
        throw new HttpsError("internal", "Failed to delete subcollections.");
      }

      // 🧾 Delete main user doc
      try {
        await userDocRef.delete();
        console.log("✅ User document deleted.");
        result.firestoreDeleted = true;
      } catch (err) {
        console.error("❌ Failed deleting user document:", err);
        throw new HttpsError("internal", "Failed to delete user document.");
      }

      // 🗃️ Delete user storage
      try {
        const bucket = storage.bucket('recipevault-bg-ai.firebasestorage.app');
        console.log(`🧺 Deleting files with prefix: users/${uid}/`);
        await bucket.deleteFiles({ prefix: `users/${uid}/` });
        console.log(`🗑️ Deleted all storage for users/${uid}/`);
        result.storageDeleted = true;
      } catch (err) {
        console.error("❌ Failed deleting storage files:", err);
        throw new HttpsError("internal", "Failed to delete user storage.");
      }

      // 🔐 Delete Firebase Auth user (final step)
      try {
        console.log("🔒 Deleting user from Firebase Auth...");
        await auth.deleteUser(uid);
        console.log("👤 Firebase Auth user deleted.");
        result.authDeleted = true;
      } catch (err) {
        console.error(`❌ Failed deleting Firebase Auth user ${uid}:`, err);
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
  }
);