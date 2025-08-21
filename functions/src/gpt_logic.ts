import OpenAI from "openai";
import {
  enforceAndConsume,
  incrementMonthlyUsage, // used only for refund on failure
} from "./usage_service.js";

// 📦 Response structure from GPT
type GptRecipeResponse = {
  formattedRecipe: string;
  notes?: string;
};

const MODEL = "gpt-3.5-turbo"; // ✅ legacy model kept for consistency

// 🌍 Map locale → human-readable language name + labels
const LOCALE_META: Record<
  string,
  {
    languageName: string;
    labels: {
      title: string;
      ingredients: string;
      instructions: string;
      hints: string;
      noTips: string;
    };
  }
> = {
  en: { languageName: "English", labels: { title: "Title", ingredients: "Ingredients", instructions: "Instructions", hints: "Hints & Tips", noTips: "No additional tips provided." } },
  en_GB: { languageName: "British English", labels: { title: "Title", ingredients: "Ingredients", instructions: "Instructions", hints: "Hints & Tips", noTips: "No additional tips provided." } },
  bg: { languageName: "Bulgarian", labels: { title: "Заглавие", ingredients: "Съставки", instructions: "Приготвяне", hints: "Съвети & Трикове", noTips: "Няма допълнителни съвети." } },
  cs: { languageName: "Czech", labels: { title: "Název", ingredients: "Suroviny", instructions: "Postup", hints: "Tipy a triky", noTips: "Žádné další tipy." } },
  da: { languageName: "Danish", labels: { title: "Titel", ingredients: "Ingredienser", instructions: "Fremgangsmåde", hints: "Tips & Tricks", noTips: "Ingen yderligere tips." } },
  de: { languageName: "German", labels: { title: "Titel", ingredients: "Zutaten", instructions: "Zubereitung", hints: "Tipps & Hinweise", noTips: "Keine zusätzlichen Tipps." } },
  el: { languageName: "Greek", labels: { title: "Τίτλος", ingredients: "Υλικά", instructions: "Εκτέλεση", hints: "Συμβουλές & Κόλπα", noTips: "Δεν υπάρχουν επιπλέον συμβουλές." } },
  es: { languageName: "Spanish", labels: { title: "Título", ingredients: "Ingredientes", instructions: "Preparación", hints: "Consejos y trucos", noTips: "Sin consejos adicionales." } },
  fr: { languageName: "French", labels: { title: "Titre", ingredients: "Ingrédients", instructions: "Préparation", hints: "Astuces & Conseils", noTips: "Aucune astuce supplémentaire." } },
  ga: { languageName: "Irish (Gaeilge)", labels: { title: "Teideal", ingredients: "Comhábhair", instructions: "Modh", hints: "Leideanna & Cleasa", noTips: "Gan leideanna breise." } },
  it: { languageName: "Italian", labels: { title: "Titolo", ingredients: "Ingredienti", instructions: "Preparazione", hints: "Consigli & Suggerimenti", noTips: "Nessun consiglio aggiuntivo." } },
  nl: { languageName: "Dutch", labels: { title: "Titel", ingredients: "Ingrediënten", instructions: "Bereiding", hints: "Tips & Tricks", noTips: "Geen extra tips." } },
  pl: { languageName: "Polish", labels: { title: "Tytuł", ingredients: "Składniki", instructions: "Przygotowanie", hints: "Wskazówki i porady", noTips: "Brak dodatkowych wskazówek." } },
  cy: { languageName: "Welsh", labels: { title: "Teitl", ingredients: "Cynhwysion", instructions: "Paratoi", hints: "Awgrymiadau a Chynghorion", noTips: "Dim awgrymiadau pellach." } },
};

// 🔠 Normalise things like "en-GB" → "en_GB" → fallback
function resolveLocaleMeta(locale: string | undefined) {
  if (!locale) return LOCALE_META.en_GB;
  const norm = locale.replace("-", "_");
  if (LOCALE_META[norm]) return LOCALE_META[norm];
  const primary = norm.split(/[_-]/)[0];
  return LOCALE_META[primary] ?? LOCALE_META.en_GB;
}

/**
 * 🎨 Formats a recipe into a consistent structure in the user’s locale,
 * with transactional quota enforcement and refund on failure.
 *
 * @param usageKind - "recipeUsage" for native recipes, "translatedRecipeUsage" for translated ones
 */
export async function generateFormattedRecipe(
  uid: string,
  text: string,
  sourceLang: string,
  targetLocale: string,
  usageKind: "recipeUsage" | "translatedRecipeUsage" = "recipeUsage"
): Promise<string> {
  if (!uid) throw new Error("❌ gpt: Missing UID for usage enforcement");

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("❌ gpt: Missing OPENAI_API_KEY in environment variables");

  const { languageName, labels } = resolveLocaleMeta(targetLocale);
  const openai = new OpenAI({ apiKey });

  // 🚦 Consume quota BEFORE GPT call
  await enforceAndConsume(uid, usageKind, 1);

  try {
    const systemPrompt = `
You are a recipe assistant. The original recipe was written in ${sourceLang.toUpperCase()}, but the text below is already translated (if translation was necessary).

Write the final output in **${languageName}** and follow that language's spelling and culinary conventions (units, ingredient names). Keep a clear, friendly tone.

Your job is to:
1) Use the exact section labels shown below, localised for ${languageName}.
2) Ensure ingredients use "- " bullets (a dash and a space) and remove duplicates.
3) Keep a numbered list for steps.
4) If there are no tips, use the provided localised placeholder.

Format exactly like this:

---
${labels.title}: <title>

${labels.ingredients}:
- item 1
- item 2

${labels.instructions}:
1. Step one.
2. Step two.

${labels.hints}:
- Add advice, substitutions or serving suggestions.
- If not available, use: "${labels.noTips}"
---

Only return a single JSON object in this format:
{
  "formattedRecipe": "<formatted recipe>",
  "notes": "<optional notes or tips, or '${labels.noTips}'>"
}
`.trim();

    const userPrompt = `Here is the recipe text:\n"""\n${text}\n"""`;

    // 🧠 GPT call
    const completion = await openai.chat.completions.create({
      model: MODEL,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.3,
      max_tokens: 1500,
    });

    const rawContent = completion.choices[0]?.message?.content?.trim();
    if (!rawContent) throw new Error("❌ gpt: Empty response from model");

    let parsed: GptRecipeResponse;
    try {
      parsed = JSON.parse(rawContent) as GptRecipeResponse;
    } catch {
      console.error("❌ gpt: Failed to parse GPT response:", rawContent);
      throw new Error("Invalid GPT response format");
    }

    if (!parsed.formattedRecipe) {
      throw new Error("❌ gpt: Missing 'formattedRecipe' key in GPT response");
    }

    const formatted = parsed.formattedRecipe.trim();
    const notes = (parsed.notes || "").trim();

    return notes ? `${formatted}\n\n${labels.hints}:\n${notes}` : formatted;
  } catch (err) {
    // ❗ Refund credit if GPT fails
    try {
      await incrementMonthlyUsage(uid, usageKind, -1);
    } catch (refundErr) {
      console.error("⚠️ gpt: Refund of usage failed:", refundErr);
    }
    throw err;
  }
}

export default generateFormattedRecipe;