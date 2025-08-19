// functions/src/rc-verify.ts
import * as crypto from "crypto";

/**
 * Verify RevenueCat webhook signature
 *
 * @param rawBody - The raw request body (Buffer, not parsed JSON)
 * @param signatureHeader - Value of `X-Webhook-Signature` header
 * @param sharedSecret - The RevenueCat webhook secret (from env)
 * @returns true if the signature is valid, false otherwise
 */
export function verifyRevenueCatSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined | null,
  sharedSecret: string
): boolean {
  if (!signatureHeader || !sharedSecret) return false;

  const expected = crypto
    .createHmac("sha256", sharedSecret)
    .update(rawBody)
    .digest("hex");

  // Use constant-time comparison to prevent timing attacks
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, "utf8"),
      Buffer.from(signatureHeader, "utf8")
    );
  } catch {
    return false; // lengths mismatch or bad input
  }
}