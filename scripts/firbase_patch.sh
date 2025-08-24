(await (require("firebase-admin").initializeApp({ projectId: "recipevault-bg-ai" }).firestore().doc("users/ViYANuh3qbYEXd0mFSXBJwsyvXH3").set({
  productId: "home_chef_monthly",
  tier: "home_chef",
  entitlementStatus: "active",
  expiresAt: null,
  graceUntil: null,
  lastEntitlementEventAt: require("firebase-admin").firestore.FieldValue.serverTimestamp()
}, { merge: true })), "✅ Patched user doc for ViYANuh3qbYEXd0mFSXBJwsyvXH3 → home_chef")