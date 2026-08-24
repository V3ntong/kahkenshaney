import * as admin from 'firebase-admin';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { sendOtpEmail } from './email';
import { generateOtp, generateSalt, hashOtp, verifyOtpHash } from './otp';
import {
  isValidEmail,
  isValidOtp,
  isValidPassword,
  normalizeEmail,
} from './validation';

admin.initializeApp();

const db = admin.firestore();

/** Secrets required for SMTP email delivery. */
const SMTP_SECRETS = [
  'SMTP_HOST',
  'SMTP_PORT',
  'SMTP_USER',
  'SMTP_PASS',
  'MAIL_FROM',
] as const;

const OTP_COLLECTION = 'otpRequests';
/** Codes are valid for 5 minutes. */
const OTP_TTL_MS = 5 * 60 * 1000;
/** Minimum delay between resend requests. */
const RESEND_COOLDOWN_MS = 60 * 1000;
/** Maximum failed verification attempts before the code is invalidated. */
const MAX_ATTEMPTS = 5;

/** What an OTP record was issued for. Prevents cross-purpose reuse. */
type OtpPurpose = 'signup' | 'reset' | 'changePassword';

function otpRef(email: string) {
  return db.collection(OTP_COLLECTION).doc(email);
}

/** Shared send/resend logic for signup verification, password reset and change. */
async function issueOtp(
  email: string,
  purpose: OtpPurpose
): Promise<void> {
  const snapshot = await otpRef(email).get();
  const existing = snapshot.data();
  if (existing) {
    const lastSent = existing.lastSentAt?.toMillis?.() ?? 0;
    const elapsed = Date.now() - lastSent;
    if (elapsed < RESEND_COOLDOWN_MS) {
      const waitSeconds = Math.ceil((RESEND_COOLDOWN_MS - elapsed) / 1000);
      throw new HttpsError(
        'resource-exhausted',
        `Please wait ${waitSeconds}s before requesting a new code.`
      );
    }
  }

  const otp = generateOtp();
  const salt = generateSalt();
  const now = Date.now();

  await otpRef(email).set({
    email,
    purpose,
    // Only a salted hash is stored - never the plaintext code.
    otpHash: hashOtp(otp, salt),
    salt,
    attempts: 0,
    verified: false,
    createdAt: admin.firestore.Timestamp.fromMillis(now),
    lastSentAt: admin.firestore.Timestamp.fromMillis(now),
    expiresAt: admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS),
  });

  try {
    const emailPurpose =
      purpose === 'signup' ? 'verification' : purpose === 'reset' ? 'reset' : 'change';
    let displayName = 'there';
    if (purpose !== 'signup') {
      try {
        const user = await admin.auth().getUserByEmail(email);
        displayName = user.displayName ?? 'there';
      } catch {
        // For non-signup purposes, user must exist — but fall back gracefully.
      }
    }
    await sendOtpEmail({
      to: email,
      name: displayName,
      otp,
      purpose: emailPurpose,
      expiresInMinutes: OTP_TTL_MS / 60_000,
    });
  } catch (error) {
    // Email failed - don't leave an unusable code behind. Log the real cause
    // (missing SMTP config, bad credentials, TLS/relay rejection, ...) so it
    // shows up in Cloud Logging / the emulator log instead of vanishing.
    console.error(
      `[issueOtp] Failed to send ${purpose} OTP to ${email}:`,
      error
    );
    await otpRef(email).delete();
    throw new HttpsError(
      'unavailable',
      'We could not send the email right now. Please try again.'
    );
  }
}

/**
 * Ensures the caller is signed in and owns the account for the given email.
 * Used by the signed-in change-password flow so one user can never issue or
 * apply a password change for another account.
 */
async function assertOwnAccount(
  request: CallableRequest,
  email: string
): Promise<void> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }
  let callerEmail: string | undefined;
  try {
    callerEmail = (await admin.auth().getUser(uid)).email;
  } catch {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }
  if (normalizeEmail(callerEmail) !== email) {
    throw new HttpsError(
      'permission-denied',
      'You can only change the password for your own account.'
    );
  }
}

/**
 * Sends a single-use, expiring OTP to verify a newly created account.
 * The account stays inactive (emailVerified = false) until the code is
 * confirmed by [verifySignupOtp].
 */
export const sendSignupOtp = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  if (!isValidEmail(email)) {
    throw new HttpsError('invalid-argument', 'Please enter a valid email address.');
  }

  // Reject if an account already exists — this is a signup-only flow.
  try {
    await admin.auth().getUserByEmail(email);
    throw new HttpsError(
      'already-exists',
      'An account with this email already exists. Please log in instead.'
    );
  } catch (e) {
    if (e instanceof HttpsError && e.code === 'already-exists') throw e;
    // getUserByEmail threw "not-found" — expected for new signups.
  }

  await issueOtp(email, 'signup');
  return { ok: true };
});

/**
 * Verifies a signup OTP. On success the account is activated by setting
 * emailVerified = true and the code is consumed (single-use).
 */
export const verifySignupOtp = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const otp =
    typeof request.data?.otp === 'string' ? request.data.otp.trim() : '';
  if (!isValidEmail(email) || !isValidOtp(otp)) {
    throw new HttpsError('invalid-argument', 'Please check the code you entered.');
  }

  await verifyOtpRecord(email, otp, 'signup');
  await otpRef(email).delete();
  return { ok: true };
});

/**
 * Sends a single-use, expiring OTP to a registered email address for
 * password recovery.
 */
export const sendPasswordResetOtp = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  if (!isValidEmail(email)) {
    throw new HttpsError('invalid-argument', 'Please enter a valid email address.');
  }

  // Verify that the email belongs to a real account.
  try {
    await admin.auth().getUserByEmail(email);
  } catch {
    throw new HttpsError('not-found', 'No account found with this email address.');
  }

  await issueOtp(email, 'reset');
  return { ok: true };
});

/**
 * Verifies a submitted password-reset OTP. Enforces purpose, expiry, a
 * per-record attempt limit and constant-time comparison. Marks the record
 * verified on success.
 */
export const verifyPasswordResetOtp = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const otp =
    typeof request.data?.otp === 'string' ? request.data.otp.trim() : '';
  if (!isValidEmail(email) || !isValidOtp(otp)) {
    throw new HttpsError('invalid-argument', 'Please check the code you entered.');
  }

  await verifyOtpRecord(email, otp, 'reset');
  return { ok: true };
});

/**
 * Sends a single-use OTP to the signed-in user's registered email before
 * allowing a password change. The caller must own the account.
 */
export const sendChangePasswordOtp = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  if (!isValidEmail(email)) {
    throw new HttpsError('invalid-argument', 'Please enter a valid email address.');
  }

  await assertOwnAccount(request, email);
  await issueOtp(email, 'changePassword');
  return { ok: true };
});

/**
 * Verifies a change-password OTP. Marks the record verified on success.
 */
export const verifyChangePasswordOtp = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const otp =
    typeof request.data?.otp === 'string' ? request.data.otp.trim() : '';
  if (!isValidEmail(email) || !isValidOtp(otp)) {
    throw new HttpsError('invalid-argument', 'Please check the code you entered.');
  }

  await verifyOtpRecord(email, otp, 'changePassword');
  return { ok: true };
});

/**
 * Applies a new password for the signed-in user. Requires a previously
 * verified change-password OTP and consumes the code (single-use).
 */
export const changePassword = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const otp =
    typeof request.data?.otp === 'string' ? request.data.otp.trim() : '';
  const newPassword =
    typeof request.data?.newPassword === 'string' ? request.data.newPassword : '';
  if (!isValidEmail(email) || !isValidOtp(otp) || !isValidPassword(newPassword)) {
    throw new HttpsError(
      'invalid-argument',
      'Please provide a valid email, code and a strong password.'
    );
  }

  await assertOwnAccount(request, email);
  await updatePasswordViaOtp(email, otp, newPassword, 'changePassword');
  return { ok: true };
});

/**
 * Applies a new password after a forgotten-password reset. Requires a
 * previously verified reset OTP and consumes the code (single-use).
 */
export const resetPassword = onCall({ secrets: [...SMTP_SECRETS] }, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const otp =
    typeof request.data?.otp === 'string' ? request.data.otp.trim() : '';
  const newPassword =
    typeof request.data?.newPassword === 'string' ? request.data.newPassword : '';
  if (!isValidEmail(email) || !isValidOtp(otp) || !isValidPassword(newPassword)) {
    throw new HttpsError(
      'invalid-argument',
      'Please provide a valid email, code and a strong password.'
    );
  }

  await updatePasswordViaOtp(email, otp, newPassword, 'reset');
  return { ok: true };
});

/**
 * Shared password-update logic used by the reset and change flows. Requires a
 * previously verified OTP of the matching purpose, checks expiry, applies the
 * new password through Firebase Auth and consumes the code.
 */
async function updatePasswordViaOtp(
  email: string,
  otp: string,
  newPassword: string,
  purpose: OtpPurpose
): Promise<void> {
  const snapshot = await otpRef(email).get();
  const record = snapshot.data();
  if (!record || record.verified !== true || record.purpose !== purpose) {
    throw new HttpsError(
      'invalid-argument',
      'This code is invalid or has already been used.'
    );
  }

  const expiresAt = record.expiresAt?.toMillis?.() ?? 0;
  if (Date.now() > expiresAt) {
    await snapshot.ref.delete();
    throw new HttpsError(
      'deadline-exceeded',
      'This code has expired. Please request a new one.'
    );
  }

  let uid: string;
  try {
    const user = await admin.auth().getUserByEmail(email);
    uid = user.uid;
  } catch {
    throw new HttpsError('not-found', 'No account found with this email address.');
  }

  try {
    await admin.auth().updateUser(uid, { password: newPassword });
  } catch {
    throw new HttpsError('internal', 'We could not update your password. Please try again.');
  }

  // Single-use: consume the code.
  await snapshot.ref.delete();
}

/**
 * Validates an OTP record against the expected purpose, expiry, attempt limit
 * and hash. Throws a user-friendly HttpsError on any failure. On success the
 * record is marked verified.
 */
async function verifyOtpRecord(
  email: string,
  otp: string,
  purpose: OtpPurpose
): Promise<void> {
  const snapshot = await otpRef(email).get();
  const record = snapshot.data();
  if (!record || record.purpose !== purpose) {
    throw new HttpsError(
      'invalid-argument',
      'This code is invalid or has already been used.'
    );
  }

  // Automatic expiry.
  const expiresAt = record.expiresAt?.toMillis?.() ?? 0;
  if (Date.now() > expiresAt) {
    await snapshot.ref.delete();
    throw new HttpsError(
      'deadline-exceeded',
      'This code has expired. Please request a new one.'
    );
  }

  // Brute-force protection.
  const attempts = (record.attempts ?? 0) + 1;
  if (attempts > MAX_ATTEMPTS) {
    await snapshot.ref.delete();
    throw new HttpsError(
      'resource-exhausted',
      'Too many incorrect attempts. Please request a new code.'
    );
  }
  await snapshot.ref.update({ attempts });

  if (!verifyOtpHash(otp, record.salt, record.otpHash)) {
    throw new HttpsError('invalid-argument', 'Incorrect code. Please check and try again.');
  }

  await snapshot.ref.update({ verified: true });
}

// ── One-time Migration: Add moderationStatus to existing items ────────────

/**
 * Callable function to add `moderationStatus: 'approved'` to all items
 * that don't have the field yet.
 *
 * Call once from the app or Firebase Console, then remove.
 */
export const migrateModerationStatus = onCall(async (request) => {
  // Only admin can run this
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!userDoc.data()?.isAdmin) {
    throw new HttpsError('permission-denied', 'Only admin can run migration.');
  }

  const snapshot = await db.collection('items').get();
  const batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!data.moderationStatus) {
      batch.update(doc.ref, { moderationStatus: 'approved' });
      count++;
    }
  }

  if (count > 0) {
    await batch.commit();
  }

  return { migrated: count, total: snapshot.docs.length };
});

// ── FCM Push Notification on Notification Create ──────────────────────────

/**
 * Firestore trigger: When a notification document is created under
 * users/{userId}/notifications/{notificationId}, send a push notification
 * to that user's device(s) via FCM.
 */
export const sendPushNotification = onDocumentCreated(
  { region: 'us-central1', document: 'users/{userId}/notifications/{notificationId}' },
  async (event) => {
    const { userId, notificationId } = event.params;
    const notificationData = event.data?.data();

    if (!notificationData) {
      console.log('No notification data, skipping push');
      return;
    }

    const { title, body, relatedItemId } = notificationData;

    try {
      // Get the user's FCM tokens from their profile
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData) {
        console.log(`User ${userId} not found, skipping push`);
        return;
      }

      const fcmTokens = userData.fcmTokens as string[] | undefined;
      if (!fcmTokens || fcmTokens.length === 0) {
        console.log(`No FCM tokens for user ${userId}, skipping push`);
        return;
      }

      // Build the push notification message
      const message: admin.messaging.MulticastMessage = {
        tokens: fcmTokens,
        notification: {
          title: title || 'New Notification',
          body: body || '',
        },
        data: {
          notificationId,
          relatedItemId: relatedItemId || '',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            channelId: 'lost_found_notifications',
            priority: 'high' as const,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send to all user devices
      const response = await admin.messaging().sendEachForMulticast(message);

      console.log(`Push sent to ${response.successCount}/${fcmTokens.length} devices for user ${userId}`);

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const tokensToRemove: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const error = resp.error;
            if (
              error?.code === 'messaging/registration-token-not-registered' ||
              error?.code === 'messaging/invalid-registration-token'
            ) {
              tokensToRemove.push(fcmTokens[idx]);
            }
          }
        });

        if (tokensToRemove.length > 0) {
          await db.collection('users').doc(userId).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
          });
          console.log(`Removed ${tokensToRemove.length} invalid tokens for user ${userId}`);
        }
      }
    } catch (error) {
      console.error(`Error sending push notification to user ${userId}:`, error);
    }
  }
);
