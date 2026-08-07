import { createHash, randomBytes, randomInt, timingSafeEqual } from 'crypto';

/**
 * Generates a cryptographically secure 6-digit OTP (100000-999999 inclusive).
 */
export function generateOtp(): string {
  return String(randomInt(100000, 1000000));
}

/** Random per-record salt so equal OTPs never share the same hash. */
export function generateSalt(): string {
  return randomBytes(16).toString('hex');
}

/**
 * OTPs are never stored in plaintext. We store a salted SHA-256 hash.
 */
export function hashOtp(otp: string, salt: string): string {
  return createHash('sha256').update(`${salt}:${otp}`).digest('hex');
}

/** Constant-time comparison to avoid timing side-channels. */
export function verifyOtpHash(
  otp: string,
  salt: string,
  expectedHash: string
): boolean {
  const actual = Buffer.from(hashOtp(otp, salt), 'hex');
  const expected = Buffer.from(expectedHash, 'hex');
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}
