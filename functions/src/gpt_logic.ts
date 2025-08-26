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
const MODEL = (process.env.GPT_MODEL ?? "").trim() || "gpt-4o-mini";

/** Lazy singleton (don’t construct at module import) */
let _openai: OpenAI | null = null;
function getOpenAI(): OpenAI {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("❌ gpt: Missing OPENAI_API_KEY");
  if (_openai) return _openai;
  _openai = new OpenAI({ apiKey: key });
  return _openai;
}

// ──────────────────────────────────────────────────────────
// Locale metadata (labels must match your Flutter parser)
// ──────────────────────────────────────────────────────────
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

function resolveLocaleMeta(locale?: string) {
  if (!locale) return LOCALE_META.en_GB;
  const norm = locale.replace("-", "_");
  if (LOCALE_META[norm]) return LOCALE_META[norm];
  const primary = norm.split(/[_-]/)[0];
  return LOCALE_META[primary] ?? LOCALE_META.en_GB;
}

// Avoid adding a duplicate “Hints & Tips” section
function hasHintsSection(text: string, hintsLabel: string): boolean {
  const pattern = new RegExp(`^\\s*${escapeRegex(hintsLabel)}\\s*:`, "im");
  return pattern.test(text);
}

function escapeRegex(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Minimal pre-clean + hard cap to reduce tokens */
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

/** Extract "{labels.title}: ..." value if present (single line). */
function extractLabeledTitle(text: string, titleLabel: string): string | null {
  const re = new RegExp(`^\\s*${escapeRegex(titleLabel)}\\s*:\\s*(.+)$`, "im");
  const m = text.match(re);
  return m?.[1]?.trim() || null;
}

/** Has a Markdown H1 anywhere ("# Something"). */
function hasH1(text: string): boolean {
  return /^#\s+.+/m.test(text);
}

/** Ensure we have both a top "# Title" and a labeled "Title: ...". */
function ensureTitlePresence(
  formatted: string,
  labels: { title: string; ingredients: string }
): string {
  let out = formatted.trim();

  // First, try to grab title from labeled line
  let title = extractLabeledTitle(out, labels.title);

  // If no labeled title, try to infer from a first H1 line
  if (!title) {
    const h1Match = out.match(/^#\s+(.+)$/m);
    if (h1Match?.[1]) title = h1Match[1].trim();
  }

  // If still no title, infer from the first non-empty line before Ingredients
  if (!title) {
    const ingRe = new RegExp(`^\\s*${escapeRegex(labels.ingredients)}\\s*:`, "im");
    const ingIndex = out.search(ingRe);
    if (ingIndex > 0) {
      const pre = out.slice(0, ingIndex).split(/\n/).map(s => s.trim()).filter(Boolean);
      if (pre.length) title = pre[pre.length - 1];
    }
  }

  // Final fallback
  if (!title || !title.trim()) title = "Untitled";

  // Ensure a top H1 exists
  if (!hasH1(out)) {
    out = `# ${title}\n\n${out}`;
  }

  // Ensure we have a labeled title line somewhere (put it under the H1 if missing)
  if (!extractLabeledTitle(out, labels.title)) {
    // Insert after top H1 block
    const parts = out.split(/\n/);
    const h1Idx = parts.findIndex(l => /^#\s+/.test(l));
    if (h1Idx >= 0) {
      parts.splice(h1Idx + 1, 0, `${labels.title}: ${title}`, "");
      out = parts.join("\n");
    } else {
      // should never happen because we added H1 above
      out = `${labels.title}: ${title}\n\n${out}`;
    }
  }

  return out;
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

  // 🚦 Consume quota BEFORE GPT call
  await enforceAndConsume(uid, usageKind, 1);

  const { languageName, labels } = resolveLocaleMeta(targetLocale);
  const input = precompress(text);

  try {
    const systemPrompt = [
      `You are a recipe formatter. The original was ${sourceLang.toUpperCase()}, but the input you receive may already be translated.`,
      `Write the final recipe in **${languageName}** using local culinary terms and units.`,
      ``,
      `Use EXACTLY these section headers (do not vary or translate these labels further):`,
      `- "${labels.title}:"`,
      `- "${labels.ingredients}:"`,
      `- "${labels.instructions}:"`,
      `- "${labels.hints}:"`,
      ``,
      `Formatting rules:`,
      `• Start the output with a single top-level Markdown heading: "# {TITLE_TEXT}".`,
      `• Immediately below it, include a line "${labels.title}: {TITLE_TEXT}".`,
      `• ${labels.ingredients}: each ingredient must be on its own line starting with "- " (dash+space).`,
      `• ${labels.instructions}: a numbered list starting "1. ", "2. ", etc.`,
      `• ${labels.hints}: a bulleted list using "- ". If there are no tips, include a single line with: "${labels.noTips}".`,
      ``,
      `Respond ONLY with JSON (no prose, no code fences). Use keys:`,
      `  - "formattedRecipe": string containing the final formatted text with the exact headers above (including the H1 and the "${labels.title}:" line),`,
      `  - "notes": optional string with extra hints/tips or "${labels.noTips}".`,
    ].join("\n");

    const userPrompt = `Recipe text to format:\n"""\n${input}\n"""`;

    console.info({ msg: "🤖 gpt: calling model", uid, usageKind, model: MODEL });

    const completion = await withRetries(() =>
      getOpenAI().chat.completions.create({
        model: MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.2,                 // more consistent output
        max_tokens: 1100,                 // enough for the whole card
        response_format: { type: "json_object" }, // ✅ guaranteed JSON (no ``` fences)
      })
    );

    const jsonText = completion.choices[0]?.message?.content?.trim();
    if (!jsonText) throw new Error("❌ gpt: Empty response from model");

    let parsed: GptRecipeResponse;
    try {
      parsed = JSON.parse(jsonText) as GptRecipeResponse;
    } catch (_e) {
      console.error("❌ gpt: JSON parse failed", { jsonText });
      throw new Error("Invalid JSON from model");
    }

    if (!parsed.formattedRecipe) {
      throw new Error("❌ gpt: Missing 'formattedRecipe' in model output");
    }

    // Normalize title presence defensively (in case the model slips)
    let formatted = ensureTitlePresence(parsed.formattedRecipe.trim(), {
      title: labels.title,
      ingredients: labels.ingredients,
    });

    const notes = (parsed.notes || "").trim() || labels.noTips;

    console.info({ msg: "✅ gpt: recipe formatted", uid, usageKind, chars: formatted.length });

    // If GPT already included the Hints section in formattedRecipe, don't add another.
    if (hasHintsSection(formatted, labels.hints)) return formatted;

    // Otherwise, append a single Hints block once (keeps Flutter parser happy)
    return `${formatted}\n\n${labels.hints}:\n- ${notes}`;
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