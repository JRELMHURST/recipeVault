// functions/src/firebase.ts

import { setGlobalOptions } from 'firebase-functions/v2'; // ✅ Import setGlobalOptions
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';

// ✅ Set default region for all Cloud Functions
setGlobalOptions({ region: 'europe-west2' });

// 🏁 Initialise Firebase Admin SDK (idempotent)
try {
  initializeApp();
  console.log('✅ Firebase Admin initialised.');
} catch (e: any) {
  if (!/already exists/u.test(e.message)) {
    console.error('❌ Firebase Admin init failed:', e);
    throw e;
  } else {
    console.log('ℹ️ Firebase Admin already initialised.');
  }
}

// 🔥 Firestore instance for re-use
export const firestore = getFirestore();

// 🧱 Export full admin instance if needed elsewhere
export default admin;