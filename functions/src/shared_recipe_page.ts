import { onRequest } from 'firebase-functions/v2/https';
import { firestore } from './firebase.js'; // Shared Firebase instance

export const sharedRecipePage = onRequest(
  { region: 'europe-west2' },
  async (req, res) => {
    const pathParts = req.path.split('/');
    const recipeId = pathParts[pathParts.length - 1];

    if (!recipeId || recipeId.trim() === '') {
      res.status(400).send('<h1>Bad Request: Missing recipe ID</h1>');
      return;
    }

    try {
      const doc = await firestore.collection('shared_recipes').doc(recipeId).get();

      if (!doc.exists) {
        res.status(404).send('<h1>Recipe Not Found</h1>');
        return;
      }

      const recipe = doc.data();
      const title = escapeHtml(recipe?.title || 'A Recipe on RecipeVault');
      const description = 'View and save this recipe with RecipeVault.';
      const formattedText = escapeHtml(recipe?.formattedText || '');
      const previewText = formattedText
        .split('\n')
        .slice(0, 8) // Show top 8 lines of recipe
        .join('<br>');

      const imageUrl = recipe?.imageUrl?.startsWith('http')
        ? recipe.imageUrl
        : 'https://recipes.badger-creations.co.uk/assets/icon/round_vaultLogo.png';
      const pageUrl = `https://recipes.badger-creations.co.uk/shared/${recipeId}`;

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

    <!-- Smart App Banner for iOS -->
    <meta name="apple-itunes-app" content="app-id=6748146354, app-argument=${pageUrl}" />

    <meta name="viewport" content="width=device-width, initial-scale=1" />

    <script>
      window.onload = function () {
        window.location.href = 'recipevault://shared/${recipeId}';
        setTimeout(() => {
          window.location.href = 'https://apps.apple.com/app/id6748146354';
        }, 2000);
      };
    </script>
  </head>
  <body style="font-family: sans-serif; text-align: center; margin-top: 4rem;">
    <img src="${imageUrl}" alt="Recipe image" style="max-width: 80%; border-radius: 8px;" />
    <h1>${title}</h1>
    <p>${description}</p>
    <div style="max-width: 600px; margin: 2rem auto; padding: 1rem; text-align: left; background: #f9f9f9; border-radius: 6px;">
      <h3>Recipe Preview:</h3>
      <p style="white-space: pre-line; line-height: 1.5; font-size: 15px;">
        ${previewText}
      </p>
    </div>
    <p style="margin-top: 3rem; font-size: 14px; color: #666;">
      If the RecipeVault app doesn’t open automatically, <br/>you’ll be redirected to the App Store shortly.
    </p>
  </body>
</html>`;

      res.set('Cache-Control', 'public, max-age=300');
      res.status(200).send(html);
    } catch (error) {
      console.error('❌ Error generating shared recipe page:', error);
      res.status(500).send('Internal Server Error');
    }
  }
);

// Escape HTML to prevent injection
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}