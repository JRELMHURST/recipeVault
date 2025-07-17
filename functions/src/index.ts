// Ensure Firebase Admin is initialised once
import './firebase.js';

// Export each callable function
export { extractAndFormatRecipe } from './extractAndFormatRecipe.js';
export { deleteAccount } from './delete_account.js';
export { sharedRecipePage } from './shared_recipe_page.js';
export { seedDefaultRecipes } from './seed_default_recipes.js';