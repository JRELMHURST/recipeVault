import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, WriteBatch } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/**
 * 🔄 Safely refresh a user's view of global recipes.
 *
 * - Merge-only (non-destructive).
 * - Copies translations/availableLocales & provenance.
 * - Does NOT overwrite user favourites, categories, images, or edited text.
 * - Sets createdAt only for new docs; always bumps updatedAt.
 */
export const refreshGlobalRecipesForUser = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    logger.error('❌ refreshGlobalRecipesForUser: unauthenticated request');
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  logger.info(`🔁 Safe refresh of global recipes for user: ${uid}`);

  try {
    const globalsSnap = await db.collection('global_recipes').get();
    if (globalsSnap.empty) {
      logger.warn('⚠️ No global recipes found.');
      throw new HttpsError('not-found', 'No global recipes available.');
    }

    const userRecipesRef = db.collection(`users/${uid}/recipes`);
    const userSnap = await userRecipesRef.get();
    const existingIds = new Set(userSnap.docs.map((d) => d.id));

    const toCopy = globalsSnap.docs; // refresh all known globals
    if (!toCopy.length) {
      logger.info(`ℹ️ Nothing to refresh for ${uid}.`);
      return { success: true, copiedCount: 0 };
    }

    // Batch in chunks (Firestore hard limit: 500 ops)
    const CHUNK = 490;
    const groups = chunk(toCopy, CHUNK);

    let copiedCount = 0;

    for (const group of groups) {
      const batch: WriteBatch = db.batch();

      for (const doc of group) {
        const g = doc.data() as any;
        const recipeId = doc.id;

        // Only copy non-destructive, locale-friendly fields.
        // Keep user-owned fields (isFavourite, categories, imageUrl, title/ingredients/etc.) untouched.
        const patch: Record<string, any> = {
          id: recipeId,
          userId: uid,
          isGlobal: true,
          sourceGlobalId: recipeId,
          // carry across translations map & available locales so the app can render per-locale at runtime
          ...(g.translations ? { translations: g.translations } : {}),
          ...(g.availableLocales ? { availableLocales: g.availableLocales } : {}),
          // keep a reference to upstream meta without overriding user fields
          ...(g.updatedAt ? { globalUpdatedAt: g.updatedAt } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        };

        // If this user doesn't have the doc yet, set createdAt
        if (!existingIds.has(recipeId)) {
          patch.createdAt = g.createdAt ?? FieldValue.serverTimestamp();
        }

        batch.set(userRecipesRef.doc(recipeId), patch, { merge: true });
        copiedCount++;
      }

      await batch.commit();
    }

    // Update user's last sync timestamp
    await db.doc(`users/${uid}`).set(
      { lastGlobalSync: FieldValue.serverTimestamp() },
      { merge: true }
    );

    logger.info(`✅ Safely refreshed ${copiedCount} global recipe(s) for user: ${uid}`);
    return { success: true, copiedCount };
  } catch (err: any) {
    logger.error('❌ refreshGlobalRecipesForUser failed:', err);
    throw new HttpsError('internal', err?.message || 'Failed to refresh global recipes.');
  }
});