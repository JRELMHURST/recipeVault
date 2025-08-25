// functions/src/getPublicStats.ts
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { firestore } from "./firebase.js";

function setCorsHeaders(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

export const getPublicStats = onRequest(async (req, res) => {
  try {
    // 🌍 Handle CORS preflight
    if (req.method === "OPTIONS") {
      setCorsHeaders(res);
      res.status(204).send("");
      return;
    }

    // 👤 Count users
    const usersSnap = await firestore.collection("users").count().get();
    const totalUsers = usersSnap.data().count ?? 0;

    // 🥘 Count recipes across all users
    const recipesSnap = await firestore.collectionGroup("recipes").count().get();
    const totalRecipes = recipesSnap.data().count ?? 0;

    const payload = {
      users: totalUsers,
      recipes: totalRecipes,
      timestamp: Date.now(),
      isoTimestamp: new Date().toISOString(),
    };

    // ✅ Success
    setCorsHeaders(res);
    res.status(200).json(payload);

    logger.info("📊 stats: Public stats fetched successfully", payload);
  } catch (error) {
    setCorsHeaders(res);
    logger.error("❌ stats: Error fetching public stats", { error });
    res.status(500).json({ error: "Failed to fetch public stats" });
  }
});