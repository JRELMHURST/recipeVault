import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

export const seedDefaultRecipes = onRequest(async (_req, res) => {
  const now = new Date();

  const globalRecipes = [
    {
      id: 'breakfast-smoothie',
      userId: 'global',
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
      imageUrl: 'https://firebasestorage.googleapis.com/v0/b/recipevault-bg-ai.firebasestorage.app/o/global_recipes%2Fbreakfast-smoothie.jpg?alt=media&token=271e30bd-aee9-4dc9-a2ef-440ad516e126',
      categories: ['Breakfast'],
      isFavourite: false,
      originalImageUrls: [],
      hints: ['Try adding a spoonful of peanut butter for protein'],
      translationUsed: false,
      isGlobal: true,
      createdAt: now,
    },
    {
      id: 'poached-egg',
      userId: 'global',
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
      imageUrl: 'https://firebasestorage.googleapis.com/v0/b/recipevault-bg-ai.firebasestorage.app/o/global_recipes%2Fpoached_egg_final.jpg?alt=media&token=c3a1ff30-7f53-4cf9-b7d1-669a72204c63',
      categories: ['Brunch'],
      isFavourite: false,
      originalImageUrls: [],
      hints: ['Use the freshest eggs you can for best results'],
      translationUsed: false,
      isGlobal: true,
      createdAt: now,
    },
    {
      id: 'puff-pastry-pizza',
      userId: 'global',
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
      imageUrl: 'https://firebasestorage.googleapis.com/v0/b/recipevault-bg-ai.firebasestorage.app/o/global_recipes%2Fpuff_pastry_pizza_final.jpg?alt=media&token=613d4ee1-15f3-4d29-9582-492bb39b0930',
      categories: ['Dinner'],
      isFavourite: false,
      originalImageUrls: [],
      hints: ['Add sliced olives or peppers for extra flavour'],
      translationUsed: false,
      isGlobal: true,
      createdAt: now,
    },
  ];

  try {
    const batch = db.batch();
    const collection = db.collection('global_recipes');

    for (const recipe of globalRecipes) {
      const docRef = collection.doc(recipe.id);
      batch.set(docRef, recipe, { merge: true });
    }

    await batch.commit();
    logger.info(`✅ Seeded ${globalRecipes.length} global recipes.`);
    res.status(200).json({ success: true, count: globalRecipes.length });
  } catch (error: any) {
    logger.error('❌ Failed to seed global recipes', error);
    res.status(500).json({ success: false, error: error.message });
  }
});