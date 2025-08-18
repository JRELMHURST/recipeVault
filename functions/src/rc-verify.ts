// functions/src/rc-verify.ts
import * as crypto from 'crypto';

export function verifyRevenueCatSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined,
  sharedSecret: string
): boolean {
  if (!signatureHeader) return false;
  const expected = crypto
    .createHmac('sha256', sharedSecret)
    .update(rawBody)
    .digest('hex');
  // case-insensitive compare
  return expected.toLowerCase() === signatureHeader.toLowerCase();
}