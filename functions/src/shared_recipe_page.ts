import { onRequest } from 'firebase-functions/v2/https';
import { firestore } from './firebase.js'; // shared Firebase instance

export const sharedRecipePage = onRequest(
  {
    region: 'europe-west2',
  },
  async (req, res) => {
    const pathParts = req.path.split('/');
    const recipeId = pathParts[pathParts.length - 1];

    try {
      const doc = await firestore.collection('shared_recipes').doc(recipeId).get();

      if (!doc.exists) {
        res.status(404).send('<h1>Recipe Not Found</h1>');
        return;
      }

      const recipe = doc.data();
      const title = escapeHtml(recipe?.title || 'A Recipe on RecipeVault');
      const description = 'View and save this recipe with RecipeVault.';
      const imageUrl =
        recipe?.imageUrl || 'https://recipevault.app/assets/icon/round_vaultLogo.png';
      const pageUrl = `https://recipevault.app/shared/${recipeId}`;

      const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>${title}</title>

    <!-- Open Graph -->
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    <meta property="og:image" content="${imageUrl}" />
    <meta property="og:url" content="${pageUrl}" />
    <meta name="twitter:card" content="summary_large_image" />

    <!-- Smart App Banner -->
    <meta name="apple-itunes-app" content="app-id=6748146354, app-argument=${pageUrl}" />

    <meta name="viewport" content="width=device-width, initial-scale=1" />

    <!-- App Redirect -->
    <script>
      window.onload = function () {
        window.location.href = 'recipevault://shared/${recipeId}';
        setTimeout(() => {
          window.location.href = 'https://apps.apple.com/app/id6748146354';
        }, 2000);
      };
    </script>
  </head>
  <body style="font-family: sans-serif; text-align: center; margin-top: 5rem;">
    <img src="${imageUrl}" alt="Recipe image" style="max-width: 80%; border-radius: 8px;" />
    <h1>${title}</h1>
    <p>${description}</p>
    <p>Opening the RecipeVault app...</p>
  </body>
</html>`;

      res.set('Cache-Control', 'public, max-age=300');
      res.status(200).send(html);
    } catch (error) {
      console.error('Error generating shared recipe page:', error);
      res.status(500).send('Internal Server Error');
    }
  }
);

// Escape function to prevent HTML injection
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}