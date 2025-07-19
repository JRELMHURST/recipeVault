import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions';

setGlobalOptions({ region: 'europe-west2' });

const db = getFirestore();

export const copyGlobalRecipesToUser = onDocumentCreated('users/{userId}', async (event) => {
  const userId = event.params.userId;
  logger.info(`👤 New user created: ${userId}. Copying global recipes...`);

  const globalSnapshot = await db.collection('global_recipes').get();
  if (globalSnapshot.empty) {
    logger.warn('⚠️ No global recipes found to copy');
    return;
  }

  const userRecipesRef = db.collection(`users/${userId}/recipes`);
  const userSnapshot = await userRecipesRef.get();
  const existingIds = new Set(userSnapshot.docs.map(doc => doc.id));

  const batch = db.batch();
  let copiedCount = 0;

  for (const doc of globalSnapshot.docs) {
    const globalRecipe = doc.data();
    const recipeId = doc.id;

    if (existingIds.has(recipeId)) {
      logger.info(`🔁 Skipped existing recipe ${recipeId} for user ${userId}`);
      continue;
    }

    const newDocRef = userRecipesRef.doc(recipeId);
    batch.set(newDocRef, {
      ...globalRecipe,
      userId,
      isGlobal: true,
      createdAt: globalRecipe.createdAt ?? FieldValue.serverTimestamp(),
    });
    copiedCount++;
  }

  await batch.commit();
  logger.info(`✅ Copied ${copiedCount} global recipe(s) to user ${userId}`);
});