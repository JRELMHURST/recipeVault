import OpenAI from "openai";

/**
 * Uses GPT to format a translated recipe text into a consistent structure.
 * Ensures consistent Hints & Tips inclusion, robust JSON handling, and UK English conventions.
 */
export async function generateFormattedRecipe(
  text: string,
  sourceLang: string
): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("❌ Missing OPENAI_API_KEY in environment variables");
  }

  const openai = new OpenAI({ apiKey });

  const systemPrompt = `
You are a UK-based recipe assistant. The original recipe was written in ${sourceLang.toUpperCase()}, but the text below has already been translated into UK English.

Your job is to:
1. Ensure all spelling and measurements follow British English conventions (e.g. grammes, litres, aubergine, courgette).
2. Format the recipe using the layout below, even if some sections are empty:

---
Title: <title>

Ingredients:
- item 1
- item 2

Instructions:
1. Step one
2. Step two

Hints & Tips:
- Add any helpful advice, substitutions or serving suggestions.
- If not available, return a placeholder like "No additional tips provided."
---

Return only a single JSON object **inside a JSON code block** like this:

\`\`\`json
{
  "formattedRecipe": "<formatted recipe text here>",
  "notes": "<extracted hints and tips or 'No additional tips provided.'>"
}
\`\`\`
`.trim();

  const userPrompt = `Here is the recipe text:\n"""\n${text}\n"""`;

  const completion = await openai.chat.completions.create({
    model: "gpt-3.5-turbo",
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt },
    ],
    temperature: 0.3,
    max_tokens: 1500,
  });

  const rawContent = completion.choices[0]?.message?.content?.trim() || "";

  // ✅ Strip markdown code block (any trailing ``` or leading ```json etc.)
  const jsonText = rawContent
    .replace(/^```json\s*/i, '')
    .replace(/```$/, '')
    .trim();

  try {
    const parsed = JSON.parse(jsonText);

    if (!parsed || typeof parsed.formattedRecipe !== "string") {
      throw new Error("Missing or invalid 'formattedRecipe' in GPT response");
    }

    const formatted = parsed.formattedRecipe.trim();
    const notes = (parsed.notes?.trim() || "No additional tips provided.").replace(/^[-•]\s*/, "");

    return `${formatted}\n\nHints & Tips:\n${notes}`;
  } catch (err) {
    console.error("❌ Failed to parse GPT response:", rawContent.slice(0, 300));
    throw new Error("Invalid GPT response format – could not parse recipe JSON.");
  }
}