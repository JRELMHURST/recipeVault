// functions/src/firebase.ts

import admin from "firebase-admin";
import { initializeApp } from "firebase-admin/app";

// 🏁 Initialise Firebase Admin SDK (idempotent)
try {
  initializeApp();
  console.log("✅ Firebase Admin initialised.");
} catch (e: any) {
  if (!/already exists/u.test(e.message)) {
    console.error("❌ Firebase Admin init failed:", e);
    throw e;
  } else {
    console.log("ℹ️ Firebase Admin already initialised.");
  }
}

// 🔥 Firestore instance for re-use
export const firestore = admin.firestore();

// 🧱 Export full admin instance if needed elsewhere
export default admin;