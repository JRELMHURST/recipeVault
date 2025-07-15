// functions/src/firebase.ts

import admin from 'firebase-admin';
import { initializeApp } from 'firebase-admin/app';

try {
  initializeApp(); // Only initialise if not already done
} catch (e: any) {
  if (!/already exists/u.test(e.message)) {
    throw e;
  }
}

export const firestore = admin.firestore();
export default admin;