// functions/src/index.ts

import "./firebase"; // Ensures Firebase is initialised only once

export { extractAndFormatRecipe } from "./extractAndFormatRecipe";
export { deleteAccount } from "./delete_account";
export { cleanupOldDeletions } from "./cleanupOldDeletions";