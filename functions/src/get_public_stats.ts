import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { firestore } from "./firebase.js";

export const getPublicStats = onRequest(async (req, res) => {
  try {
    // 🌍 Handle CORS preflight
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.status(204).send("");
      return; // ✅ stop execution after preflight
    }

    // 👤 Count users
    const usersSnap = await firestore.collection("users").count().get();
    const totalUsers = usersSnap.data().count ?? 0;

    // 🥘 Count recipes across all users
    const recipesSnap = await firestore.collectionGroup("recipes").count().get();
    const totalRecipes = recipesSnap.data().count ?? 0;

    // ✅ Success
    res.set("Access-Control-Allow-Origin", "*");
    res.status(200).json({
      users: totalUsers,
      recipes: totalRecipes,
      timestamp: Date.now(),
    });
    logger.info("📊 stats: Public stats fetched successfully.", {
      users: totalUsers,
      recipes: totalRecipes,
    });
  } catch (error) {
    logger.error("❌ stats: Error fetching public stats", { error });
    res.status(500).json({ error: "Failed to fetch public stats" });
  }
});