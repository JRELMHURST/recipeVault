// functions/src/gpt_logic.ts
import OpenAI from "openai";
import {
  enforceAndConsume,
  incrementMonthlyUsage, // refund on failure
} from "./usage_service.js";

// ──────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────
type GptRecipeResponse = {
  formattedRecipe: string;
  notes?: string;
};

// Prefer env override but keep your default
const MODEL = process.env.GPT_MODEL?.trim() || "gpt-4o-mini";

// Reuse one client (avoids TLS handshakes per request)
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// ──────────────────────────────────────────────────────────
// Locale metadata (unchanged API surface)
// ──────────────────────────────────────────────────────────
const LOCALE_META: Record<
  string,
  {
    languageName: string;
    labels: { title: string; ingredients: string; instructions: string; hints: string; noTips: string };
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

function resolveLocaleMeta(locale?: string) {
  if (!locale) return LOCALE_META.en_GB;
  const norm = locale.replace("-", "_");
  if (LOCALE_META[norm]) return LOCALE_META[norm];
  const primary = norm.split(/[_-]/)[0];
  return LOCALE_META[primary] ?? LOCALE_META.en_GB;
}

// Avoid adding a duplicate “Hints” section
function hasHintsSection(text: string, hintsLabel: string): boolean {
  const pattern = new RegExp(`^\\s*${hintsLabel}\\s*:`, "im");
  return pattern.test(text);
}

// ──────────────────────────────────────────────────────────
/** Minimal pre‑clean + hard cap to reduce tokens */
function precompress(input: string, maxChars = 6500): string {
  const cleaned = input
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\r/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  return cleaned.length > maxChars ? cleaned.slice(0, maxChars) : cleaned;
}

/** Tiny retry helper for transient 429/5xx */
async function withRetries<T>(fn: () => Promise<T>, tries = 2): Promise<T> {
  let last: any;
  let delay = 300;
  for (let i = 0; i < tries; i++) {
    try {
      return await fn();
    } catch (e: any) {
      const code = e?.status ?? e?.code;
      const retriable = code === 429 || (code >= 500 && code < 600);
      last = e;
      if (!retriable || i === tries - 1) break;
      await new Promise((r) => setTimeout(r, delay + Math.floor(Math.random() * 150)));
      delay *= 2;
    }
  }
  throw last;
}

// ──────────────────────────────────────────────────────────
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
  if (!process.env.OPENAI_API_KEY) throw new Error("❌ gpt: Missing OPENAI_API_KEY");

  const { languageName, labels } = resolveLocaleMeta(targetLocale);

  // 🚦 Consume quota BEFORE GPT call
  await enforceAndConsume(uid, usageKind, 1);

  const input = precompress(text);

  try {
    const systemPrompt = [
      `You are a recipe formatter. The source text was originally ${sourceLang.toUpperCase()}, but the input you receive is already in the target language if a translation happened earlier.`,
      `Write the final recipe in **${languageName}**, using local culinary conventions (units/terms).`,
      `Output sections using these exact labels:`,
      `- ${labels.title}`,
      `- ${labels.ingredients}`,
      `- ${labels.instructions}`,
      `- ${labels.hints}`,
      `Rules:`,
      `• Ingredients use "- " bullet lines (dash + space). No duplicates.`,
      `• Instructions are a numbered list.`,
      `• If there are no tips, use: "${labels.noTips}".`,
      `Respond ONLY with JSON (no prose), using keys: "formattedRecipe" (string) and optional "notes" (string).`,
    ].join("\n");

    const userPrompt = `Recipe text:\n"""\n${input}\n"""`;

    console.info({ msg: "🤖 gpt: calling model", uid, usageKind, model: MODEL });

    const completion = await withRetries(() =>
      openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.2,          // a bit lower for determinism/consistency
        max_tokens: 1100,          // plenty for your sections, keeps latency down
        response_format: { type: "json_object" }, // ✅ guaranteed JSON
      })
    );

    const jsonText = completion.choices[0]?.message?.content?.trim();
    if (!jsonText) throw new Error("❌ gpt: Empty response from model");

    let parsed: GptRecipeResponse;
    try {
      parsed = JSON.parse(jsonText) as GptRecipeResponse;
    } catch (e) {
      console.error("❌ gpt: JSON parse failed", { jsonText });
      throw new Error("Invalid JSON from model");
    }

    if (!parsed.formattedRecipe) {
      throw new Error("❌ gpt: Missing 'formattedRecipe' in model output");
    }

    const formatted = parsed.formattedRecipe.trim();
    const notes = (parsed.notes || "").trim() || labels.noTips;

    console.info({ msg: "✅ gpt: recipe formatted", uid, usageKind, chars: formatted.length });

    // Don’t duplicate Hints if the model included it
    if (hasHintsSection(formatted, labels.hints)) return formatted;

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