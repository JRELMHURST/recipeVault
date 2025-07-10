// functions/src/delete_account.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

const firestore = getFirestore();
const auth = getAuth();
const storage = getStorage();

export const deleteAccount = onCall({ region: "europe-west2" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  try {
    console.log(`🔥 Deleting account for UID: ${uid}`);
    const userDocRef = firestore.collection("users").doc(uid);

    // Delete subcollections
    try {
      const subcollections = await userDocRef.listCollections();
      for (const col of subcollections) {
        const snap = await col.get();
        const batch = firestore.batch();
        snap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`🧹 Deleted ${snap.size} docs from ${col.id}`);
      }
    } catch (err) {
      console.error("❌ Failed deleting subcollections:", err);
    }

    // Delete user document
    try {
      await userDocRef.delete();
      console.log("✅ User document deleted.");
    } catch (err) {
      console.error("❌ Failed deleting user doc:", err);
    }

    // Delete storage files
    try {
      const bucketName = "recipevault-bg-ai.appspot.com"; // ✅ CORRECT bucket ID
      await storage.bucket(bucketName).deleteFiles({ prefix: `users/${uid}/` });
      console.log(`🗑️ Deleted storage files for user ${uid}`);
    } catch (err) {
      console.error("❌ Failed deleting storage files:", err);
    }

    // Delete Firebase Auth user
    try {
      await auth.deleteUser(uid);
      console.log("👤 Firebase Auth user deleted.");
    } catch (err) {
      console.error("❌ Failed deleting auth user:", err);
    }

    return { success: true };
  } catch (error: any) {
    console.error("❌ Account deletion failed:", error);
    throw new HttpsError("internal", error?.message || "Account deletion failed");
  }
});