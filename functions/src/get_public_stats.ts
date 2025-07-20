import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

export const getPublicStats = onRequest(async (req, res) => {
  try {
    const db = getFirestore();

    // Count users
    const usersSnap = await db.collection('users').count().get();
    const totalUsers = usersSnap.data().count || 0;

    // Count all recipes in all users' subcollections
    const recipesSnap = await db.collectionGroup('recipes').count().get();
    const totalRecipes = recipesSnap.data().count || 0;

    // Optional: count images processed (if you store this anywhere)
    // const statsDoc = await db.doc('stats/aggregate').get();
    // const totalImages = statsDoc.exists ? statsDoc.data()?.imagesProcessed || 0 : 0;

    res.set('Access-Control-Allow-Origin', '*'); // Make it embeddable
    res.status(200).json({
      users: totalUsers,
      recipes: totalRecipes,
      // images: totalImages,
      timestamp: Date.now(),
    });
  } catch (error) {
    logger.error('Error fetching public stats:', error);
    res.status(500).json({ error: 'Failed to fetch public stats' });
  }
});