import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";

setGlobalOptions({ region: "europe-west2" });

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

export const firestore = getFirestore();
export { Timestamp, FieldValue };