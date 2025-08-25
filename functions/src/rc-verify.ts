// functions/src/rc-verify.ts
import * as crypto from "crypto";

/**
 * Verify RevenueCat webhook signature.
 *
 * RevenueCat signs the raw body with HMAC-SHA256 using the shared secret.
 * We compare in constant time using `crypto.timingSafeEqual` to prevent timing attacks.
 *
 * @param rawBody        Raw request body (Buffer, not parsed JSON)
 * @param signatureHeader Value of `X-Webhook-Signature` header (hex string)
 * @param sharedSecret    The RevenueCat webhook secret (from env)
 * @returns true if signature is valid, false otherwise
 */
export function verifyRevenueCatSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined | null,
  sharedSecret: string | undefined | null
): boolean {
  if (!signatureHeader || !sharedSecret) {
    console.warn("⚠️ Missing RC signature header or shared secret");
    return false;
  }

  try {
    const expected = crypto
      .createHmac("sha256", sharedSecret)
      .update(rawBody)
      .digest(); // Buffer

    const received = Buffer.from(signatureHeader, "hex");

    if (received.length !== expected.length) {
      console.warn("⚠️ RC signature length mismatch");
      return false;
    }

    const valid = crypto.timingSafeEqual(expected, received);
    if (!valid) {
      console.warn("⚠️ RC signature mismatch");
    }
    return valid;
  } catch (err) {
    console.error("❌ RC signature verification failed:", err);
    return false;
  }
}