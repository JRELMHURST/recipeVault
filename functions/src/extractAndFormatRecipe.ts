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
      console.log("📄 Merged OCR preview:\n", mergedText.slice(0, 500));

      const systemPrompt = `
You are a recipe formatting assistant.

First, check the text language.
- If the text is NOT in UK English, translate it into clean UK English.
- If it IS already in English, leave it as-is.

Then format the text using this exact structure:
---
Title: <title>

Ingredients:
- item 1
- item 2

Instructions:
1. Step one
2. Step two
---

Do NOT include markdown symbols, language names, or commentary. Only output the final recipe.
`;

      const userPrompt = `Here is the text to process:\n"""\n${mergedText}\n"""`;

      const completion = await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: systemPrompt.trim(),
          },
          {
            role: "user",
            content: userPrompt.trim(),
          },
        ],
        temperature: 0.3,
        max_tokens: 1500,
      });

      const formatted = completion.choices[0]?.message?.content?.trim();
      console.log("✅ GPT output (preview):", formatted?.slice(0, 300));

      // Delete uploaded screenshots from Firebase Storage
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

      return { formattedRecipe: formatted };
    } catch (err: any) {
      console.error("❌ Failure in extractAndFormatRecipe:", err);
      throw new functions.https.HttpsError("internal", "Failed to process recipe");
    }
  }
);