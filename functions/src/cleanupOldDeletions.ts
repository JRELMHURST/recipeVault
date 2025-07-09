import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { initializeApp } from "firebase-admin/app";

initializeApp();

const firestore = getFirestore();
const auth = getAuth();
const storage = getStorage();

export const cleanupOldDeletions = onSchedule(
  {
    schedule: "every day 03:00", // UTC time
    region: "europe-west2",
  },
  async () => {
    const now = Date.now();
    const THIRTY_DAYS = 1000 * 60 * 60 * 24 * 30;

    const snapshot = await firestore
      .collection("users")
      .where("markedForDeletionAt", "<", now - THIRTY_DAYS)
      .get();

    if (snapshot.empty) {
      logger.info("✅ No users to delete.");
      return;
    }

    for (const doc of snapshot.docs) {
      const uid = doc.id;
      logger.info(`🗑️ Deleting user: ${uid}`);

      try {
        // Delete recipes
        const recipes = await firestore.collection(`users/${uid}/recipes`).listDocuments();
        for (const r of recipes) await r.delete();

        // Delete associated Storage files
        const [files] = await storage.bucket().getFiles({ prefix: `users/${uid}/` });
        for (const file of files) {
          try {
            await file.delete();
          } catch (err) {
            logger.warn(`⚠️ Failed to delete file: ${file.name}`, err);
          }
        }

        // Delete Firestore user doc
        await firestore.doc(`users/${uid}`).delete();

        // Delete Auth account
        await auth.deleteUser(uid);

        logger.info(`✅ Fully deleted user: ${uid}`);
      } catch (err) {
        logger.error(`❌ Error deleting user ${uid}:`, err);
      }
    }
  }
);