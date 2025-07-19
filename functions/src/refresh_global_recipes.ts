import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

/**
 * 🔄 Refreshes a user's global recipes by re-copying all documents from /global_recipes
 * to /users/{uid}/recipes, overwriting any existing global ones.
 */
export const refreshGlobalRecipesForUser = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    logger.error('❌ refreshGlobalRecipesForUser: unauthenticated request');
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  logger.info(`🔁 Refreshing global recipes for user: ${uid}`);

  try {
    const globalSnapshot = await db.collection('global_recipes').get();
    if (globalSnapshot.empty) {
      logger.warn('⚠️ No global recipes found.');
      throw new HttpsError('not-found', 'No global recipes available.');
    }

    const userRecipesRef = db.collection(`users/${uid}/recipes`);
    const batch = db.batch();
    let copiedCount = 0;

    for (const doc of globalSnapshot.docs) {
      const globalRecipe = doc.data();
      const recipeId = doc.id;

      const docRef = userRecipesRef.doc(recipeId);
      batch.set(docRef, {
        ...globalRecipe,
        userId: uid,
        isGlobal: true,
        createdAt: globalRecipe.createdAt ?? FieldValue.serverTimestamp(),
      });
      copiedCount++;
    }

    // 🕒 Update the user's last sync timestamp
    const userDocRef = db.doc(`users/${uid}`);
    batch.update(userDocRef, {
      lastGlobalSync: FieldValue.serverTimestamp(),
    });

    await batch.commit();
    logger.info(`✅ Refreshed ${copiedCount} global recipe(s) for user: ${uid}`);

    return { success: true, copiedCount };
  } catch (err: any) {
    logger.error('❌ refreshGlobalRecipesForUser failed:', err);
    throw new HttpsError('internal', err?.message || 'Failed to refresh global recipes.');
  }
});