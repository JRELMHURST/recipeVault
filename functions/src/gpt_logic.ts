import OpenAI from "openai";
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export async function generateFormattedRecipe(text: string, sourceLang: string): Promise<string> {
  const systemPrompt = `
You are a recipe assistant. The original recipe was written in ${sourceLang.toUpperCase()}, but the text below has been translated into UK English.

Format the following recipe using this template:
---
Title: <title>

Ingredients:
- item 1
- item 2

Instructions:
1. Step one
2. Step two
---
Only return a single JSON object:
{
  "formattedRecipe": "<formatted recipe>"
}`.trim();

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
  const parsed = JSON.parse(rawContent || "{}");

  if (!parsed || typeof parsed.formattedRecipe !== "string") {
    throw new Error("Invalid GPT response format");
  }

  return parsed.formattedRecipe;
}