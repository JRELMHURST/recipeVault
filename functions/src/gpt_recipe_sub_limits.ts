import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const firestore = getFirestore();

/**
 * Checks if the user is within their 7-day trial period.
 */
async function isTrialActive(uid: string): Promise<boolean> {
  const userDoc = await firestore.collection("users").doc(uid).get();
  const startStr = userDoc.data()?.trialStartDate;
  if (!startStr) return false;

  const start = new Date(startStr);
  const now = new Date();
  const days = (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
  return days < 7;
}

/**
 * Enforces AI recipe generation limit based on subscription tier.
 */
export async function enforceGptRecipePolicy(uid: string, tier: string): Promise<void> {
  const monthKey = new Date().toISOString().slice(0, 7); // e.g. "2025-07"

  // ✅ Allow unlimited usage if on active trial
  if (await isTrialActive(uid)) {
    console.log("🟢 AI recipe allowed: user is in trial period.");
    return;
  }

  if (tier === "taster") {
    const usageDoc = await firestore.collection("aiUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 3) {
      throw new HttpsError("resource-exhausted", "Taster plan allows up to 3 recipe generations per month.");
    }
  }

  if (tier === "homeChef") {
    const usageDoc = await firestore.collection("aiUsage").doc(uid).get();
    const used = usageDoc.data()?.[monthKey] || 0;
    if (used >= 20) {
      throw new HttpsError("resource-exhausted", "Home Chef plan allows up to 20 recipe generations per month.");
    }
  }

  // ✅ Master Chef = unlimited
}

/**
 * Increments GPT recipe usage count after successful generation.
 */
export async function incrementGptRecipeUsage(uid: string, tier: string): Promise<void> {
  // ✅ No increment if on trial or master
  if (tier === "masterChef" || await isTrialActive(uid)) return;

  const monthKey = new Date().toISOString().slice(0, 7);
  await firestore.collection("aiUsage").doc(uid)
    .set({ [monthKey]: FieldValue.increment(1) }, { merge: true });
}