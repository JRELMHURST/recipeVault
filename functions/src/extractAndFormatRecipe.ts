import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import vision from "@google-cloud/vision";
import OpenAI from "openai";
import * as dotenv from "dotenv";
import { getStorage } from "firebase-admin/storage";
import { initializeApp } from "firebase-admin/app";

dotenv.config();
initializeApp();

const visionClient = new vision.ImageAnnotatorClient();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const predefinedCategories = [
  "Main",
  "Dessert",
  "Side",
  "Vegan",
  "Vegetarian",
  "Breakfast",
  "Snack",
  "Quick"
];

export const extractAndFormatRecipe = onCall(
  { region: "europe-west2" },
  async (request) => {
    const imageUrls: string[] = request.data?.imageUrls;

    if (!Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing or invalid 'imageUrls' array"
      );
    }

    try {
      console.log(`🔍 Running OCR for ${imageUrls.length} image(s)...`);

      let detectedLanguage: string | null = null;

      const ocrTexts = await Promise.all(
        imageUrls.map(async (url, idx) => {
          const [result] = await visionClient.documentTextDetection(url);
          const document = result.fullTextAnnotation;
          if (idx === 0 && document?.pages?.length) {
            detectedLanguage = document.pages[0].property?.detectedLanguages?.[0]?.languageCode || null;
          }
          return document?.text || "";
        })
      );

      const mergedText = ocrTexts.join("\n").trim();
      console.log("📝 Merged OCR text length:", mergedText.length);
      console.log("📄 Merged OCR preview:\n", mergedText.slice(0, 500));
      console.log("🌍 Detected language:", detectedLanguage || "unknown");

const systemPrompt = `
You are a recipe assistant. Your job is three-fold:

1. If the recipe is not written in UK English, translate it into clean, natural UK English.
2. Format the input text as a recipe card using this exact format:
---
Title: <title>

Ingredients:
- item 1
- item 2

Instructions:
1. Step one
2. Step two
---

3. Then, return a JSON list of all relevant categories from this set:
${JSON.stringify(predefinedCategories)}

Your final output must be valid JSON like this:
{
  "formattedRecipe": "<recipe card text>",
  "categories": ["Main", "Quick"]
}

Do not include any commentary or explanation. Only return valid JSON.
`;

      const userPrompt = `Here is the recipe text:\n"""\n${mergedText}\n"""`;

      const completion = await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: systemPrompt.trim() },
          { role: "user", content: userPrompt.trim() }
        ],
        temperature: 0.3,
        max_tokens: 1500,
      });

      const rawContent = completion.choices[0]?.message?.content?.trim();
      console.log("✅ GPT raw output:\n", rawContent?.slice(0, 300));

      let parsed;
      try {
        parsed = JSON.parse(rawContent || "{}");

        if (
          typeof parsed !== "object" ||
          typeof parsed.formattedRecipe !== "string" ||
          !Array.isArray(parsed.categories)
        ) {
          throw new Error("Invalid structure");
        }
      } catch (err) {
        console.error("❌ Failed to parse GPT response as JSON:", err);
        throw new functions.https.HttpsError(
          "internal",
          "Invalid GPT response format"
        );
      }

      // Clean up uploaded image files
      const storage = getStorage();
      const deletedPaths: string[] = [];

      await Promise.all(
        imageUrls.map(async (url) => {
          try {
            const pathMatch = url.match(/o\/(.+?)\?.*/);
            if (!pathMatch || pathMatch.length < 2)
              throw new Error("Invalid image URL path");

            const decodedPath = decodeURIComponent(pathMatch[1]);
            await storage.bucket().file(decodedPath).delete();
            deletedPaths.push(decodedPath);
            console.log(`🗑️ Deleted uploaded image: ${decodedPath}`);
          } catch (err) {
            console.error("⚠️ Error deleting uploaded image:", err);
          }
        })
      );

      return {
        formattedRecipe: parsed.formattedRecipe,
        categories: parsed.categories,
        language: detectedLanguage || "unknown"
      };
    } catch (err: any) {
      console.error("❌ Failure in extractAndFormatRecipe:", err);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to process recipe"
      );
    }
  }
);