// functions/src/seed_default_recipes.ts

import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

// ⬇️ Import your localised GPT formatter (update path if needed)
import generateFormattedRecipe from './gpt_logic.js';

const db = getFirestore();

// UI/BCP-47 locales supported in your app (match l10n.yaml)
const SUPPORTED_LOCALES = [
  'en',     // English fallback
  'en-GB',  // English (UK)
  'bg',     // Bulgarian
  'cs',     // Czech
  'da',     // Danish
  'de',     // German
  'el',     // Greek
  'es',     // Spanish
  'fr',     // French
  'ga',     // Irish
  'it',     // Italian
  'nl',     // Dutch
  'pl',     // Polish
  'cy',     // Welsh
];

type RecipeBase = {
  id: string;
  title: string;
  ingredients: string[];
  instructions: string[];
  hints?: string[];
  imageUrl: string;
  categories: string[];
};

type RecipeDoc = {
  id: string;
  userId: 'global';
  title: string;
  ingredients: string[];
  instructions: string[];
  imageUrl: string;
  categories: string[];
  isFavourite: boolean;
  originalImageUrls: string[];
  hints: string[];
  translationUsed: boolean;
  isGlobal: true;
  locale: 'en-GB';
  availableLocales: string[];
  // We store the GPT output for each locale as a single formatted block + notes.
  translations: Record<string, { formatted: string; notes?: string }>;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
};

// Helper: build a plain text source to feed GPT (EN-GB base recipe)
function buildSourceText(base: RecipeBase): string {
  const ingredients = base.ingredients.map(i => `- ${i}`).join('\n');
  const instructions = base.instructions.map((s, i) => `${i + 1}. ${s}`).join('\n');
  const hints = (base.hints?.length ? base.hints.map(h => `- ${h}`).join('\n') : '').trim();

  return [
    `Title: ${base.title}`,
    ``,
    `Ingredients:`,
    ingredients,
    ``,
    `Instructions:`,
    instructions,
    ``,
    hints ? `Hints & Tips:\n${hints}` : ''
  ].join('\n').trim();
}

// Map BCP-47 → your targetLocale key (your formatter accepts "en_GB", "pl", etc.)
function toFormatterLocaleKey(locale: string): string {
  // Your LOCALE_META uses en_GB (underscore). Others are plain (pl, de, …)
  return locale === 'en-GB' ? 'en_GB' : locale;
}

export const seedDefaultRecipes = onRequest(async (req, res) => {
  try {
    // Basic CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Headers', 'content-type');
      res.status(204).send('');
      return;
    }

    const now = Timestamp.now();
    const shouldMerge = req.query.mode === 'merge';

    // ===== Base EN-GB recipes (same as your current content) =====
    const recipes: RecipeBase[] = [
      {
        id: 'breakfast-smoothie',
        title: 'Breakfast Smoothie',
        ingredients: [
          '1 ripe banana (frozen for extra creaminess)',
          '200ml semi-skimmed milk (or oat milk)',
          '1 tbsp rolled oats',
          '1 tsp honey (or maple syrup)',
          '2–3 ice cubes (optional)',
          'A pinch of cinnamon (optional)',
        ],
        instructions: [
          'Peel the banana and break into chunks.',
          'Add banana, milk, oats, and honey into a blender.',
          'Include ice cubes and a pinch of cinnamon if desired.',
          'Blend on high for 30–45 seconds until smooth and creamy.',
          'Pour into a glass and serve immediately.',
        ],
        hints: ['Try adding a spoonful of peanut butter for protein'],
        imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/recipevault-bg-ai.firebasestorage.app/o/global_recipes%2Fbreakfast-smoothie.jpg?alt=media&token=271e30bd-aee9-4dc9-a2ef-440ad516e126',
        categories: ['Breakfast'],
      },
      {
        id: 'poached-egg',
        title: 'How to Poach an Egg',
        ingredients: [
          '1 fresh egg',
          '500ml water',
          '1 tsp white vinegar (optional)',
          'Salt and pepper to taste',
          'Toasted bread, to serve',
        ],
        instructions: [
          'Fill a small saucepan with water and bring to a gentle simmer.',
          'Add vinegar to help the egg white hold together (optional).',
          'Crack the egg into a ramekin or small bowl.',
          'Stir the water to create a gentle whirlpool.',
          'Carefully slide the egg into the centre of the whirlpool.',
          'Poach for 2–3 minutes until the white is set but the yolk is soft.',
          'Lift out with a slotted spoon and drain on kitchen paper.',
          'Serve on buttered toast with salt and pepper.',
        ],
        hints: ['Use the freshest eggs you can for best results'],
        imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/recipevault-bg-ai.firebasestorage.app/o/global_recipes%2Fpoached_egg_final.jpg?alt=media&token=c3a1ff30-7f53-4cf9-b7d1-669a72204c63',
        categories: ['Brunch'],
      },
      {
        id: 'puff-pastry-pizza',
        title: 'Quick Puff Pastry Pizza',
        ingredients: [
          '1 sheet of ready-rolled puff pastry',
          '3 tbsp tomato passata or pizza sauce',
          '75g grated mozzarella cheese',
          'Cherry tomatoes, sliced',
          'Fresh basil leaves',
          'Salt and pepper to taste',
          'Olive oil, for drizzling',
        ],
        instructions: [
          'Preheat oven to 200°C (180°C fan) and line a baking tray.',
          'Unroll the puff pastry onto the tray, keeping the baking paper.',
          'Score a 1cm border around the edge (don’t cut all the way through).',
          'Spread the tomato sauce evenly inside the border.',
          'Sprinkle over mozzarella and arrange sliced tomatoes on top.',
          'Season with salt and pepper.',
          'Bake for 15–20 minutes until the pastry is golden and puffed.',
          'Top with fresh basil and a drizzle of olive oil before serving.',
        ],
        hints: ['Add sliced olives or peppers for extra flavour'],
        imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/recipevault-bg-ai.firebasestorage.app/o/global_recipes%2Fpuff_pastry_pizza_final.jpg?alt=media&token=613d4ee1-15f3-4d29-9582-492bb39b0930',
        categories: ['Dinner'],
      },
    ];

    const collection = db.collection('global_recipes');

    if (!shouldMerge) {
      // Full reset: delete existing docs (outside batch)
      const existingDocs = await collection.listDocuments();
      for (const doc of existingDocs) {
        logger.info(`🗑️ Deleting old doc: ${doc.id}`);
        await doc.delete();
      }
    }

    // Build and write docs
    for (const base of recipes) {
      const sourceText = buildSourceText(base);

      // Per-locale GPT formatting
      const translations: Record<string, { formatted: string; notes?: string }> = {};

      for (const locale of SUPPORTED_LOCALES) {
        const targetKey = toFormatterLocaleKey(locale); // e.g. en-GB → en_GB
        try {
          const formatted = await generateFormattedRecipe(
            sourceText,
            'en',            // sourceLang of the base text
            targetKey        // target locale for output labels + language
          );

          // We don’t need notes for rendering, but we can keep a placeholder if you later extend
          translations[locale] = { formatted };
          logger.info(`🌐 ${base.id} → formatted for ${locale}`);
        } catch (e) {
          logger.warn(`⚠️ GPT formatting failed for ${base.id} (${locale}). Falling back to EN-GB.`, e);
          // Fallback: store the EN-GB base text as formatted
          translations[locale] = { formatted: sourceText };
        }
      }

      const docRef = collection.doc(base.id);

      // Merge or overwrite per request
      const write: RecipeDoc = {
        id: base.id,
        userId: 'global',
        title: base.title,
        ingredients: base.ingredients,
        instructions: base.instructions,
        imageUrl: base.imageUrl,
        categories: base.categories,
        isFavourite: false,
        originalImageUrls: [],
        hints: base.hints ?? [],
        translationUsed: false,
        isGlobal: true,
        locale: 'en-GB',
        availableLocales: SUPPORTED_LOCALES,
        translations,
        createdAt: now,
        updatedAt: now,
      };

      if (shouldMerge) {
        const snap = await docRef.get();
        const createdAt =
          (snap.exists && (snap.data()?.createdAt as Timestamp | undefined)) || write.createdAt;
        await docRef.set({ ...write, createdAt, updatedAt: Timestamp.now() }, { merge: true });
      } else {
        await docRef.set(write);
      }
    }

    logger.info(
      `✅ Seeded ${recipes.length} global recipes (${shouldMerge ? 'merge' : 'reset'}) with translations for ${SUPPORTED_LOCALES.length} locales.`
    );
    res.status(200).json({
      success: true,
      mode: shouldMerge ? 'merge' : 'reset',
      count: recipes.length,
      locales: SUPPORTED_LOCALES,
    });
  } catch (error: any) {
    logger.error('❌ Failed to seed global recipes', error);
    res.status(500).json({ success: false, error: error?.message ?? 'Unknown error' });
  }
});