import { initializeApp } from "firebase-admin/app";
initializeApp();

// ✅ Import callable GPT formatter
export { generateRecipeCard } from "./generatedRecipeCard";

// (Optional) OCR image-to-text handler
// Uncomment if still needed
/*
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import vision from "@google-cloud/vision";

const visionClient = new vision.ImageAnnotatorClient();

export const extractRecipeFromImages = onRequest(
  { region: "europe-west2" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const imageUrls: string[] = req.body.imageUrls;
    if (!imageUrls || !Array.isArray(imageUrls)) {
      res.status(400).json({ error: "Missing or invalid 'imageUrls' array" });
      return;
    }

    try {
      logger.info("Starting OCR for images...", {
        imageCount: imageUrls.length,
      });

      const ocrTexts = await Promise.all(
        imageUrls.map(async (url) => {
          const [result] = await visionClient.textDetection(url);
          const detections = result.textAnnotations;
          return detections?.[0]?.description || "";
        })
      );

      const mergedText = ocrTexts.join("\n").trim();
      logger.info("Merged OCR text", { mergedLength: mergedText.length });

      res.status(200).json({ mergedText });
    } catch (err) {
      logger.error("Error during OCR processing", err);
      res.status(500).json({ error: "Failed to process recipe" });
    }
  }
);
*/