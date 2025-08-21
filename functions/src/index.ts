// functions/src/index.ts
import "./firebase.js";

// 🔐 Core callable/request handlers
export { extractAndFormatRecipe } from "./extractAndFormatRecipe.js";
export { deleteAccount } from "./delete_account.js";
export { getPublicStats } from "./get_public_stats.js";

// 🧾 RevenueCat integration
export { revenuecatWebhook } from "./revenuecat_webhook.js";
export { reconcileUserFromRC } from "./reconcile.js";