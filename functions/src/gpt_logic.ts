// functions/src/gpt_logic.ts
import OpenAI from "openai";
import {
  enforceAndConsume,
  incrementMonthlyUsage, // refund on failure
} from "./usage_service.js";

// 📦 Response structure from GPT
type GptRecipeResponse = {
  formattedRecipe: string;
  notes?: string;
};

const MODEL = "gpt-4o-mini";

// 🌍 Locale → language name + labels
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

// 🔠 Normalise locale string
function resolveLocaleMeta(locale: string | undefined) {
  if (!locale) return LOCALE_META.en_GB;
  const norm = locale.replace("-", "_");
  if (LOCALE_META[norm]) return LOCALE_META[norm];
  const primary = norm.split(/[_-]/)[0];
  return LOCALE_META[primary] ?? LOCALE_META.en_GB;
}

/**
 * 🎨 Format a recipe into a consistent structure in the user’s locale,
 * with quota enforcement and refund on failure.
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

Write the final output in **${languageName}**, using its culinary conventions (units, ingredient names).
Keep a clear, friendly tone.

Your job:
1) Use the exact section labels shown below, localised for ${languageName}.
2) Ingredients must use "- " bullets (dash + space) and no duplicates.
3) Steps must be a numbered list.
4) If no tips are present, insert the localised placeholder.

Format like:

---
${labels.title}: <title>

${labels.ingredients}:
- item 1
- item 2

${labels.instructions}:
1. Step one.
2. Step two.

${labels.hints}:
- Advice / substitutions / serving suggestions.
- Or: "${labels.noTips}"
---

Return only a JSON object in a \`\`\`json code block, like:

\`\`\`json
{
  "formattedRecipe": "<formatted recipe>",
  "notes": "<optional notes or '${labels.noTips}'>"
}
\`\`\`
`.trim();

    const userPrompt = `Here is the recipe text:\n"""\n${text}\n"""`;

    console.info({ msg: "🤖 gpt: calling model", uid, usageKind, model: MODEL });

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

    // ✅ Strip markdown code fences (` ```json`, ```JSON`, etc.)
    const jsonText = rawContent
      .replace(/^\s*```json/i, "")
      .replace(/^\s*```JSON/i, "")
      .replace(/```$/i, "")
      .trim();

    let parsed: GptRecipeResponse;
    try {
      parsed = JSON.parse(jsonText) as GptRecipeResponse;
    } catch {
      console.error("❌ gpt: Failed to parse GPT response", { rawContent });
      throw new Error("Invalid GPT response format");
    }

    if (!parsed.formattedRecipe) {
      throw new Error("❌ gpt: Missing 'formattedRecipe' key in GPT response");
    }

    const formatted = parsed.formattedRecipe.trim();
    const notes = (parsed.notes || "").trim() || labels.noTips;

    console.info({
      msg: "✅ gpt: recipe formatted",
      uid,
      usageKind,
      chars: formatted.length,
    });

    return `${formatted}\n\n${labels.hints}:\n${notes}`;
  } catch (err) {
    // ❗ Refund credit if GPT fails
    console.error("❌ gpt: error during formatting", { uid, usageKind, err });
    try {
      await incrementMonthlyUsage(uid, usageKind, -1);
    } catch (refundErr) {
      console.error("⚠️ gpt: refund of usage failed", { uid, refundErr });
    }
    throw err;
  }
}

export default generateFormattedRecipe;