import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import vision from "@google-cloud/vision";
import OpenAI from "openai";
import * as dotenv from "dotenv";

dotenv.config();

const visionClient = new vision.ImageAnnotatorClient();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

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

      const ocrTexts = await Promise.all(
        imageUrls.map(async (url) => {
          const [result] = await visionClient.textDetection(url);
          const detections = result.textAnnotations;
          return detections?.[0]?.description || "";
        })
      );

      const mergedText = ocrTexts.join("\n").trim();
      console.log("📝 Merged OCR text length:", mergedText.length);

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
${mergedText}
"""`;

      const completion = await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a recipe formatting assistant." },
          { role: "user", content: prompt },
        ],
        temperature: 0.3,
        max_tokens: 1000,
      });

      const formatted = completion.choices[0]?.message?.content?.trim();
      console.log("✅ GPT output (preview):", formatted?.slice(0, 80));

      return { formattedRecipe: formatted };
    } catch (err: any) {
      console.error("❌ Failure in extractAndFormatRecipe:", err);
      throw new functions.https.HttpsError("internal", "Failed to process recipe");
    }
  }
);