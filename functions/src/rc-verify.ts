// functions/src/rc-verify.ts
import * as crypto from "crypto";

/**
 * Verify RevenueCat webhook signature
 *
 * @param rawBody - The raw request body (Buffer, not parsed JSON)
 * @param signatureHeader - Value of `X-Webhook-Signature` header (hex string)
 * @param sharedSecret - The RevenueCat webhook secret (from env)
 * @returns true if the signature is valid, false otherwise
 */
export function verifyRevenueCatSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined | null,
  sharedSecret: string
): boolean {
  if (!signatureHeader || !sharedSecret) return false;

  try {
    // Compute expected signature as Buffer
    const expected = crypto
      .createHmac("sha256", sharedSecret)
      .update(rawBody)
      .digest(); // returns Buffer directly

    // Decode the hex signature header into a Buffer
    const received = Buffer.from(signatureHeader, "hex");

    // Constant-time comparison
    return crypto.timingSafeEqual(expected, received);
  } catch (err) {
    console.error("❌ RevenueCat signature verification failed:", err);
    return false;
  }
}