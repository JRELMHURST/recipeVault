import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions';

// ✅ Set region to europe-west2 (London)
setGlobalOptions({ region: 'europe-west2' });

const db = getFirestore();

export const seedDefaultRecipes = onCall(async (_request) => {
  const now = new Date();

  const globalRecipes = [
    {
      id: 'breakfast-smoothie',
      userId: 'global',
      title: 'Breakfast Smoothie',
      ingredients: ['1 banana', '200ml milk', '1 tbsp oats', '1 tsp honey'],
      instructions: [
        'Add all ingredients to a blender.',
        'Blend until smooth.',
        'Serve chilled.',
      ],
      imageUrl: 'https://example.com/smoothie.jpg',
      categories: ['Breakfast'],
      isFavourite: false,
      originalImageUrls: [],
      hints: [],
      translationUsed: false,
      isGlobal: true,
      createdAt: now,
    },
    {
      id: 'poached-egg',
      userId: 'global',
      title: 'How to Poach an Egg',
      ingredients: ['1 fresh egg', 'Water', 'Vinegar (optional)'],
      instructions: [
        'Boil water in a saucepan and reduce to a simmer.',
        'Crack egg into a small bowl.',
        'Create a gentle whirlpool in the water and carefully pour in the egg.',
        'Cook for 2–3 minutes, then remove with a slotted spoon.',
      ],
      imageUrl: 'https://example.com/egg.jpg',
      categories: ['Brunch'],
      isFavourite: false,
      originalImageUrls: [],
      hints: [],
      translationUsed: false,
      isGlobal: true,
      createdAt: now,
    },
    {
      id: 'puff-pastry-pizza',
      userId: 'global',
      title: 'Quick Puff Pastry Pizza',
      ingredients: ['1 sheet puff pastry', 'Tomato sauce', 'Cheese', 'Toppings'],
      instructions: [
        'Preheat oven to 200°C (180°C fan).',
        'Spread tomato sauce over pastry sheet.',
        'Add cheese and toppings.',
        'Bake for 15–20 minutes until golden and crisp.',
      ],
      imageUrl: 'https://example.com/pizza.jpg',
      categories: ['Dinner'],
      isFavourite: false,
      originalImageUrls: [],
      hints: [],
      translationUsed: false,
      isGlobal: true,
      createdAt: now,
    },
  ];

  const batch = db.batch();
  const collection = db.collection('global_recipes');

  for (const recipe of globalRecipes) {
    const docRef = collection.doc(recipe.id);
    batch.set(docRef, recipe, { merge: true }); // merge: true ensures re-runs don't break
  }

  await batch.commit();
  logger.info(`✅ Seeded ${globalRecipes.length} global recipes`);

  return { success: true, count: globalRecipes.length };
});