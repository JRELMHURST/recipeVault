import './firebase.js';

// 🔐 Existing exports
export { extractAndFormatRecipe } from './extractAndFormatRecipe.js';
export { deleteAccount } from './delete_account.js';
export { getPublicStats } from './get_public_stats.js';

// 🆕 RevenueCat integration
export { onAuthInitUser, revenuecatWebhook, reconcileUserFromRC } from './revenuecat_index.js';