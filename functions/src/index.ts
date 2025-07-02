import { initializeApp } from "firebase-admin/app";
initializeApp();

// Export combined OCR + GPT formatter
export { extractAndFormatRecipe } from "./extractAndFormatRecipe";

// (Optional) If you still want to keep separate formatter
export { generateRecipeCard } from "./generatedRecipeCard";

// (Old HTTP OCR function - deprecated)
// export { extractRecipeFromImages } from "./legacyExtractRecipe";