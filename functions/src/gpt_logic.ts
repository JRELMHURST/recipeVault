import OpenAI from "openai";

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

Please:
1. Ensure all spelling and measurements follow British English conventions (e.g. grammes, litres, aubergine, courgette).
2. Format the recipe using the following layout:

---
Title: <title>

Ingredients:
- item 1
- item 2

Instructions:
1. Step one
2. Step two
---

Only return a single JSON object in this format:
{
  "formattedRecipe": "<formatted recipe>"
}
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

  const rawContent = completion.choices[0]?.message?.content?.trim();

  try {
    const parsed = JSON.parse(rawContent || "{}");

    if (typeof parsed.formattedRecipe !== "string") {
      throw new Error("Missing 'formattedRecipe' key in GPT response");
    }

    return parsed.formattedRecipe;
  } catch (err) {
    console.error("❌ Failed to parse GPT response:", rawContent);
    throw new Error("Invalid GPT response format");
  }
}