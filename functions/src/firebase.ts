import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import * as admin from "firebase-admin";

// 🌍 Default region for all Cloud Functions (London/Europe)
setGlobalOptions({ region: "europe-west2" });

// 🏁 Initialise Firebase Admin SDK (idempotent)
try {
  initializeApp();
  console.log("✅ firebase: Admin initialised.");
} catch (e: any) {
  if (/already exists/u.test(e.message)) {
    console.log("ℹ️ firebase: Admin already initialised.");
  } else {
    console.error("❌ firebase: Admin init failed:", e);
    throw e;
  }
}

// 🔥 Firestore instance for shared use
export const firestore = getFirestore();

// 🧱 Export full admin instance if needed (auth, storage, etc.)
export default admin;