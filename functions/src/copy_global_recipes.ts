import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions';

setGlobalOptions({ region: 'europe-west2' });

const db = getFirestore();

// When a new user doc is created, copy global recipes
export const copyGlobalRecipesToUser = onDocumentCreated('users/{userId}', async (event) => {
  const userId = event.params.userId;
  logger.info(`👤 New user created: ${userId}. Copying global recipes...`);

  const globalRecipesSnapshot = await db.collection('global_recipes').get();

  if (globalRecipesSnapshot.empty) {
    logger.warn('⚠️ No global recipes found to copy');
    return;
  }

  const batch = db.batch();
  const userRecipesRef = db.collection(`users/${userId}/recipes`);

  globalRecipesSnapshot.forEach((doc) => {
    const recipe = doc.data();
    const newDocRef = userRecipesRef.doc(); // generate new doc ID
    batch.set(newDocRef, {
      ...recipe,
      userId,
      isGlobal: true,
      createdAt: new Date(),
    });
  });

  await batch.commit();
  logger.info(`✅ Copied ${globalRecipesSnapshot.size} global recipes to user ${userId}`);
});