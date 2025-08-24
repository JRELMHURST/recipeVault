// functions/src/seed_user.ts
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { firestore } from "./firebase.js";
import { FieldValue } from "firebase-admin/firestore";

/**
 * 🔑 Seed user document + usage collections when a user is first created.
 */
export const seedUserOnCreate = onDocumentCreated("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const monthKey = new Date().toISOString().slice(0, 7); // e.g. "2025-08"

  console.log(`👤 Seeding user: ${uid}`);

  // Defaults (align with reconcile_entitlement.ts + frontend subscription_service.dart)
  const defaultTier = "none";
  const defaultAccess = false;

  // ── Seed usage subcollections ───────────────────────────
  const usageKinds = ["recipeUsage", "translatedRecipeUsage", "imageUsage"];
  await Promise.all(
    usageKinds.map((kind) =>
      firestore
        .collection("users")
        .doc(uid)
        .collection(kind)
        .doc("usage")
        .set({ [monthKey]: 0 }, { merge: true })
    )
  );

  // ── Seed main user doc ──────────────────────────────────
  await firestore.collection("users").doc(uid).set(
    {
      // Identity
      createdAt: FieldValue.serverTimestamp(),
      lastLogin: FieldValue.serverTimestamp(),

      // Subscription core
      tier: defaultTier,                       // 🚨 enforcement field
      productId: "none",                       // RC productIdentifier (audit only, normalised)
      entitlementStatus: "none",               // "active" | "expired" | "none"
      expiresAt: null,                         // populated by RC webhook
      graceUntil: null,                        // populated by RC webhook
      lastEntitlementEventAt: null,            // wait for actual RC event
      entitlementHash: "seed",                 // prevents duplicate writes, explicit marker

      // Overrides / beta
      specialAccess: defaultAccess,

      // Preferences
      preferredRecipeLocale: "en-GB",
    },
    { merge: true }
  );

  console.log(`✅ User seeded: ${uid}`);
});