import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue, Timestamp, WriteBatch } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

type LocaleBlock = { formatted?: string; notes?: string | string[]; title?: string; ingredients?: string[] | string; instructions?: string[] | string; hints?: string[] | string; };
type TranslationsMap = Record<string, LocaleBlock>;

type GlobalRecipe = {
  // base fields (EN-GB in your seed)
  id?: string;
  title?: string;
  ingredients?: string[] | string;
  instructions?: string[] | string;
  hints?: string[] | string;     // ← your seed uses 'hints'
  notes?: string[] | string;     // legacy alias
  imageUrl?: string;
  categories?: string[];
  createdAt?: Timestamp;
  updatedAt?: Timestamp;

  // new seed schema
  translations?: TranslationsMap;
  availableLocales?: string[];
  locale?: string; // e.g. 'en-GB'

  // legacy shapes we’ll still tolerate
  i18n?: Record<string, { title?: string; ingredients?: string[] | string; instructions?: string[] | string; notes?: string[] | string; }>;
  [key: string]: any;
};

const FALLBACKS = ['en-GB', 'en'];

function toArray(val?: string[] | string): string[] | undefined {
  if (val == null) return undefined;
  return Array.isArray(val) ? val : [val];
}

function normaliseDesiredLocale(loc?: string): { exact?: string; lang?: string } {
  if (!loc) return {};
  const lower = loc.toLowerCase();
  // special-case en-GB key since you store it with a dash, not underscore
  if (lower.startsWith('en-gb')) return { exact: 'en-GB', lang: 'en' };
  const parts = lower.split('-');
  const lang = parts[0];
  return { exact: loc, lang }; // preserve original exact (may be 'pl-PL')
}

/** Pick the best locale block from translations/i18n/suffixes + sensible fallbacks. */
function pickLocalised(
  doc: GlobalRecipe,
  desired?: string
): { title?: string; ingredients?: string[]; instructions?: string[]; hints?: string[] } {
  const { exact, lang } = normaliseDesiredLocale(desired);

  // 1) New schema: translations map
  const tr = doc.translations as TranslationsMap | undefined;
  if (tr && typeof tr === 'object') {
    const tryKeys: string[] = [];
    if (exact) tryKeys.push(exact);
    if (lang && !tryKeys.includes(lang)) tryKeys.push(lang);
    for (const fb of FALLBACKS) if (!tryKeys.includes(fb)) tryKeys.push(fb);

    for (const k of tryKeys) {
      const blk = tr[k];
      if (!blk) continue;

      // Preferred shape is { formatted } but allow split fields if present.
      if (blk.formatted) {
        // If you later want to parse 'formatted' back into sections, do it here.
        // For now, we return undefined here so the app uses recipe.formattedForLocaleTag().
        return {
          // Don’t override title/sections from CFN if formatted exists; UI will render it.
          title: undefined,
          ingredients: undefined,
          instructions: undefined,
          hints: undefined,
        };
      }

      return {
        title: blk.title,
        ingredients: toArray(blk.ingredients),
        instructions: toArray(blk.instructions),
        hints: toArray((blk.hints ?? blk.notes) as any),
      };
    }
  }

  // 2) Legacy i18n shape
  const i18n = doc.i18n;
  if (i18n && typeof i18n === 'object') {
    const tryKeys: string[] = [];
    if (exact) tryKeys.push(exact.replace('-', '_'));
    if (lang && !tryKeys.includes(lang)) tryKeys.push(lang);
    for (const fb of FALLBACKS) if (!tryKeys.includes(fb)) tryKeys.push(fb.replace('-', '_'));

    for (const k of tryKeys) {
      const blk = i18n[k];
      if (!blk) continue;
      return {
        title: blk.title,
        ingredients: toArray(blk.ingredients),
        instructions: toArray(blk.instructions),
        hints: toArray((blk as any).hints ?? blk.notes),
      };
    }
  }

  // 3) Per-field suffixes (title_pl, title_en_GB, etc.)
  const suffixTry = (base: string): string | string[] | undefined => {
    if (exact && doc[`${base}_${exact.replace('-', '_')}`] != null) return doc[`${base}_${exact.replace('-', '_')}`];
    if (lang && doc[`${base}_${lang}`] != null) return doc[`${base}_${lang}`];
    for (const fb of FALLBACKS) {
      const key = `${base}_${fb.replace('-', '_')}`;
      if (doc[key] != null) return doc[key];
    }
    return undefined;
  };

  const tS = suffixTry('title');
  const iS = suffixTry('ingredients');
  const sS = suffixTry('instructions');
  const hS = suffixTry('hints') ?? suffixTry('notes');

  if (tS || iS || sS || hS) {
    return {
      title: (typeof tS === 'string' ? tS : undefined),
      ingredients: toArray(iS),
      instructions: toArray(sS),
      hints: toArray(hS),
    };
  }

  // 4) Fallback to base single-language fields
  return {
    title: doc.title,
    ingredients: toArray(doc.ingredients),
    instructions: toArray(doc.instructions),
    hints: toArray(doc.hints ?? doc.notes),
  };
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

export const copyGlobalRecipesToUser = onDocumentCreated('users/{userId}', async (event) => {
  const userId = event.params.userId;

  const userSnap = await db.collection('users').doc(userId).get();
  const preferredLocale: string | undefined = userSnap.get('preferredLocale') || undefined;

  logger.info(`👤 New user ${userId}; copying global recipes with locale=${preferredLocale ?? 'default'}`);

  const globalSnapshot = await db.collection('global_recipes').get();
  if (globalSnapshot.empty) {
    logger.warn('⚠️ No global recipes found to copy');
    return;
  }

  const userRecipesRef = db.collection(`users/${userId}/recipes`);
  const userSnapshot = await userRecipesRef.get();
  const existingIds = new Set(userSnapshot.docs.map((d) => d.id));

  const toCopy = globalSnapshot.docs.filter((d) => !existingIds.has(d.id));
  if (!toCopy.length) {
    logger.info(`ℹ️ All global recipes already present for ${userId}. Nothing to copy.`);
    return;
  }

  const CHUNK_SIZE = 490;
  const chunks = chunk(toCopy, CHUNK_SIZE);

  let copiedCount = 0;

  for (const group of chunks) {
    const batch: WriteBatch = db.batch();

    for (const doc of group) {
      const globalRecipe = doc.data() as GlobalRecipe;
      const recipeId = doc.id;

      const loc = pickLocalised(globalRecipe, preferredLocale);

      batch.set(userRecipesRef.doc(recipeId), {
        id: recipeId,
        userId,
        isGlobal: true,
        // Copy stable base fields; let the app render formatted locale text at runtime
        title: (loc.title ?? globalRecipe.title ?? ''),
        ingredients: (loc.ingredients ?? toArray(globalRecipe.ingredients) ?? []),
        instructions: (loc.instructions ?? toArray(globalRecipe.instructions) ?? []),
        hints: (loc.hints ?? toArray(globalRecipe.hints ?? globalRecipe.notes) ?? []),
        categories: globalRecipe.categories ?? [],
        imageUrl: globalRecipe.imageUrl ?? null,

        // Optional provenance
        sourceGlobalId: recipeId,
        locale: preferredLocale ?? (globalRecipe.locale ?? 'en-GB'),

        isFavourite: false,
        originalImageUrls: [],
        translationUsed: false,

        createdAt: globalRecipe.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      copiedCount++;
    }

    await batch.commit();
  }

  logger.info(`✅ Copied ${copiedCount} global recipe(s) to user ${userId}`);
});