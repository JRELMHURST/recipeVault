import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue, Timestamp, WriteBatch } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

type LocaleLabels = {
  title?: string;
  ingredients?: string[] | string;
  instructions?: string[] | string;
  notes?: string[] | string;
};

type GlobalRecipe = {
  // single-language fields (optional)
  title?: string;
  ingredients?: string[] | string;
  instructions?: string[] | string;
  notes?: string[] | string;

  // i18n map style (optional)
  i18n?: Record<string, LocaleLabels>;

  // or per-field suffix style (optional): title_pl, title_en_GB, etc.
  [key: string]: any;

  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

/** Normalises locale codes so 'en-GB' and 'en_GB' match the same data. */
function normaliseLocale(loc?: string): string | undefined {
  if (!loc) return undefined;
  return loc.replace('-', '_'); // store / look up as underscores
}

/** Picks the best localised variant from a global recipe with fallbacks. */
function pickLocalisedVariant(
  doc: GlobalRecipe,
  desired: string | undefined,
  fallbackChain: string[] = ['en_GB', 'en']
): LocaleLabels {
  const want = normaliseLocale(desired);

  // 1) i18n map shape: i18n: { pl: {...}, en_GB: {...} }
  if (doc.i18n && typeof doc.i18n === 'object') {
    // try exact
    if (want && doc.i18n[want]) return doc.i18n[want]!;
    // try fallbacks
    for (const fb of fallbackChain) {
      if (doc.i18n[fb]) return doc.i18n[fb]!;
    }
  }

  // 2) per-field suffix shape: title_pl, title_en_GB, etc.
  const trySuffix = (keyBase: string): string | string[] | undefined => {
    if (want && doc[`${keyBase}_${want}`] != null) return doc[`${keyBase}_${want}`];
    for (const fb of fallbackChain) {
      if (doc[`${keyBase}_${fb}`] != null) return doc[`${keyBase}_${fb}`];
    }
    return undefined;
  };

  const titleS     = trySuffix('title');
  const ingS       = trySuffix('ingredients');
  const instrS     = trySuffix('instructions');
  const notesS     = trySuffix('notes');

  if (titleS || ingS || instrS || notesS) {
    return {
      title: typeof titleS === 'string' ? titleS : titleS as any,
      ingredients: ingS as any,
      instructions: instrS as any,
      notes: notesS as any,
    };
  }

  // 3) single-language fallback (whatever the doc has)
  return {
    title: doc.title,
    ingredients: doc.ingredients,
    instructions: doc.instructions,
    notes: doc.notes,
  };
}

/** Splits an array into chunks of size n. */
function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

export const copyGlobalRecipesToUser = onDocumentCreated('users/{userId}', async (event) => {
  const userId = event.params.userId;
  const userSnap = await db.collection('users').doc(userId).get();
  const preferredLocale: string | undefined = normaliseLocale(userSnap.get('preferredLocale'));

  logger.info(`👤 New user ${userId}; copying global recipes with locale=${preferredLocale ?? 'default'}`);

  // Pull all global recipes (if you expect a lot, paginate instead of a single get())
  const globalSnapshot = await db.collection('global_recipes').get();
  if (globalSnapshot.empty) {
    logger.warn('⚠️ No global recipes found to copy');
    return;
  }

  // Find which recipe IDs the user already has
  const userRecipesRef = db.collection(`users/${userId}/recipes`);
  const userSnapshot = await userRecipesRef.get();
  const existingIds = new Set(userSnapshot.docs.map((d) => d.id));

  // Prepare writes (skip existing)
  const toCopy = globalSnapshot.docs.filter((d) => !existingIds.has(d.id));

  if (!toCopy.length) {
    logger.info(`ℹ️ All global recipes already present for ${userId}. Nothing to copy.`);
    return;
  }

  // Firestore batch limit = 500 operations; keep headroom
  const CHUNK_SIZE = 490;
  const chunks = chunk(toCopy, CHUNK_SIZE);

  let copiedCount = 0;

  for (const group of chunks) {
    const batch: WriteBatch = db.batch();

    for (const doc of group) {
      const globalRecipe = doc.data() as GlobalRecipe;
      const recipeId = doc.id;

      const localised = pickLocalisedVariant(globalRecipe, preferredLocale);

      const newDocRef = userRecipesRef.doc(recipeId);
      batch.set(newDocRef, {
        // keep a copy of the whole object if you want (handy for future re-localisation)
        // i18n: globalRecipe.i18n ?? undefined,

        // write the chosen localised view into canonical fields your app uses:
        title: localised.title ?? globalRecipe.title ?? '',
        ingredients: localised.ingredients ?? globalRecipe.ingredients ?? [],
        instructions: localised.instructions ?? globalRecipe.instructions ?? [],
        notes: localised.notes ?? globalRecipe.notes ?? [],

        userId,
        isGlobal: true,
        sourceGlobalId: recipeId,
        createdAt: globalRecipe.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        locale: preferredLocale ?? 'en_GB', // optional: note which variant was chosen
      });

      copiedCount++;
    }

    await batch.commit();
  }

  logger.info(`✅ Copied ${copiedCount} global recipe(s) to user ${userId}`);
});