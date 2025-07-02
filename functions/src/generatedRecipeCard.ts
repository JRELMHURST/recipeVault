import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import OpenAI from "openai";
import * as dotenv from "dotenv";

dotenv.config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export const generateRecipeCard = onCall(
  { region: "europe-west2" },
  async (request) => {
    const rawText = request.data?.ocrText;

    if (!rawText || typeof rawText !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "Missing or invalid ocrText");
    }

    const prompt = `
You are a recipe formatting assistant. Your job is to take messy OCR text and return a clean recipe card.
Output should be in this exact structure:

---
Title: <title>

Ingredients:
- item 1
- item 2

Instructions:
1. Step one
2. Step two
---

No extra text. Format cleanly, correct obvious OCR errors. Here's the text:
"""
${rawText}
"""`;

    try {
      const completion = await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a recipe formatting assistant." },
          { role: "user", content: prompt },
        ],
        temperature: 0.3,
        max_tokens: 1000,
      });

      const result = completion.choices[0]?.message?.content;
      return { formattedRecipe: result };
    } catch (error: unknown) {
      if (error instanceof Error) {
        console.error("OpenAI error:", error.message);
      } else {
        console.error("Unknown error occurred");
      }
      throw new functions.https.HttpsError("internal", "Failed to format recipe");
    }
  }
);