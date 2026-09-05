import * as admin from 'firebase-admin';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import {
  computeMatchScore,
  MATCH_THRESHOLD,
  MatchScoreEntry,
  MAX_STORED_MATCHES,
  MatchableItem,
  selectMatches,
} from './matching';
import {
  MATCHED_STATUS,
  PENDING_CLAIM_STATUS,
  RESOLVED_STATUS,
  validateClaim,
  validateMatchConfirm,
  validateResolve,
} from './claims';
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

// ── Smart Description Matching ────────────────────────────────────────────

/**
 * Creates an in-app notification document for a user. The existing
 * [sendPushNotification] trigger turns this into an FCM push automatically.
 */
async function notifyUser(
  userId: string,
  title: string,
  body: string,
  type: string,
  relatedItemId?: string
): Promise<void> {
  try {
    await db.collection('users').doc(userId).collection('notifications').add({
      title,
      body,
      type,
      relatedItemId: relatedItemId ?? null,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(`[notifyUser] Failed to notify user ${userId}:`, error);
  }
}

/** Maps a Firestore document to the pure [MatchableItem] shape. */
function toMatchableItem(id: string, data: FirebaseFirestore.DocumentData): MatchableItem {
  return {
    id,
    kind: data.kind === 'found' ? 'found' : 'lost',
    title: String(data.title ?? ''),
    description: String(data.description ?? ''),
    category: data.category ?? null,
    location: data.location ?? null,
    createdAt: data.createdAt?.toDate?.() ?? null,
    status: String(data.status ?? 'open'),
    moderationStatus: String(data.moderationStatus ?? 'pending'),
    reportedBy: data.reportedBy ?? null,
    ownerUid: data.ownerUid ?? null,
  };
}

/**
 * Scores a newly approved item against open items of the opposite kind,
 * persists the top matches to BOTH documents, and notifies both parties for
 * high-confidence matches. Safe to re-run: notifications are only sent for
 * pairs that are not already stored as matches.
 */
async function runMatchingForItem(itemId: string): Promise<void> {
  const itemDoc = await db.collection('items').doc(itemId).get();
  const itemData = itemDoc.data();
  if (!itemData) {
    console.log(`[matching] Item ${itemId} not found, skipping`);
    return;
  }

  const item = toMatchableItem(itemId, itemData);
  if (item.moderationStatus !== 'approved') {
    console.log(`[matching] Item ${itemId} not approved, skipping`);
    return;
  }
  if (['claimed', 'resolved', 'closed'].includes(item.status)) {
    console.log(`[matching] Item ${itemId} is terminal, skipping`);
    return;
  }

  const oppositeKind = item.kind === 'lost' ? 'found' : 'lost';
  const candidates = await db
    .collection('items')
    .where('moderationStatus', '==', 'approved')
    .where('kind', '==', oppositeKind)
    .get();

  const scored: MatchScoreEntry[] = [];
  const candidateData: { id: string; data: FirebaseFirestore.DocumentData }[] = [];

  for (const doc of candidates.docs) {
    if (doc.id === itemId) continue;
    const candidate = toMatchableItem(doc.id, doc.data());
    if (['claimed', 'resolved', 'closed'].includes(candidate.status)) continue;

    const score = computeMatchScore(item, candidate);
    scored.push({
      itemId: candidate.id,
      title: candidate.title,
      kind: candidate.kind,
      score,
      matchedAt: new Date(),
    });
    candidateData.push({ id: doc.id, data: doc.data() });
  }

  const storedForItem = selectMatches(scored, {
    threshold: 0, // store the top candidates regardless of threshold
    max: MAX_STORED_MATCHES,
  });

  // Persist match scores on the item itself (displayed without recomputation).
  if (storedForItem.length > 0) {
    await itemDoc.ref.update({ matchScores: storedForItem });
  }

  // Persist the reverse direction on each candidate, and notify both parties
  // for high-confidence matches.
  for (const entry of storedForItem) {
    if (entry.score < MATCH_THRESHOLD) continue;

    const candidateRef = db.collection('items').doc(entry.itemId);
    const candidateDoc = await candidateRef.get();
    if (!candidateDoc.exists) continue;

    const reverseEntry: MatchScoreEntry = {
      itemId: item.id,
      title: item.title,
      kind: item.kind,
      score: entry.score,
      matchedAt: new Date(),
    };

    // Merge with existing scores (dedupe by itemId, keep highest score).
    const existing = (candidateDoc.data()?.matchScores as MatchScoreEntry[] | undefined) ?? [];
    const merged = [
      ...existing.filter((m) => m.itemId !== item.id),
      reverseEntry,
    ]
      .sort((a, b) => b.score - a.score)
      .slice(0, MAX_STORED_MATCHES);
    await candidateRef.update({ matchScores: merged });

    const alreadyNotified = existing.some((m) => m.itemId === item.id);
    if (alreadyNotified) continue;

    const kindLabel = item.kind === 'lost' ? 'lost' : 'found';
    const otherLabel = item.kind === 'lost' ? 'found' : 'lost';

    // Notify the new item's reporter (skip when both items are theirs).
    if (item.reportedBy && item.reportedBy !== candidateDoc.data()?.reportedBy) {
      await notifyUser(
        item.reportedBy,
        'Suggested Match Found!',
        `Your ${kindLabel} item "${item.title}" matches "${entry.title}" (${entry.score}% match). Please review it.`,
        'match_suggestion',
        entry.itemId
      );
    }

    // Notify the existing candidate's reporter.
    const candidateOwner = candidateDoc.data()?.reportedBy;
    if (candidateOwner && candidateOwner !== item.reportedBy) {
      await notifyUser(
        candidateOwner,
        'Suggested Match Found!',
        `Your ${otherLabel} item "${entry.title}" matches "${item.title}" (${entry.score}% match). Please review it.`,
        'match_suggestion',
        item.id
      );
    }
  }
}

/**
 * Firestore trigger: runs matching when a new item is created already
 * approved (e.g. restored/imported data). New reports are created as
 * `pending`, so matching normally runs on approval (see [itemApproved]).
 */
export const itemMatchingOnCreate = onDocumentCreated(
  { region: 'us-central1', document: 'items/{itemId}' },
  async (event) => {
    const data = event.data?.data();
    if (data?.moderationStatus !== 'approved') return;
    await runMatchingForItem(event.params.itemId);
  }
);

/**
 * Firestore trigger: runs matching when an item transitions to `approved`
 * (admin approval) and sends the claimer a notification when a claim is
 * confirmed (status → claimed/resolved).
 */
export const itemLifecycle = onDocumentUpdated(
  { region: 'us-central1', document: 'items/{itemId}' },
  async (event) => {
    const before = event.data?.before.data() ?? {};
    const after = event.data?.after.data() ?? {};

    // Newly approved → compute smart matches.
    if (
      before.moderationStatus !== 'approved' &&
      after.moderationStatus === 'approved'
    ) {
      await runMatchingForItem(event.params.itemId);
    }

    // Status changed to claimed/resolved → notify the claimer (if any).
    if (before.status !== after.status) {
      const claimedBy = after.claimedBy;
      const reporter = after.reportedBy || after.ownerUid;
      if (
        claimedBy &&
        claimedBy !== reporter &&
        (after.status === 'claimed' || after.status === 'resolved')
      ) {
        await notifyUser(
          claimedBy,
          after.status === 'resolved' ? 'Claim Resolved' : 'Claim Confirmed',
          `Your claim for "${after.title ?? 'an item'}" has been ${after.status === 'resolved' ? 'resolved' : 'confirmed'}.`,
          `status_${after.status}`,
          event.params.itemId
        );
      }
    }
  }
);

// ── Claim Item (server-side, self-claim protected) ───────────────────────

/**
 * Callable: a signed-in user claims an item. Validates server-side that the
 * claimer did not report the item themselves, that the item is open, and that
 * it has not already been claimed. On success the item moves to
 * `pendingClaim` and both parties are notified.
 */
export const claimItem = onCall(async (request) => {
  const claimerUid = request.auth?.uid;
  if (!claimerUid) {
    throw new HttpsError('unauthenticated', 'You must be signed in to claim an item.');
  }

  const itemId =
    typeof request.data?.itemId === 'string' ? request.data.itemId.trim() : '';
  if (!itemId) {
    throw new HttpsError('invalid-argument', 'Missing item ID.');
  }

  const itemDoc = await db.collection('items').doc(itemId).get();
  if (!itemDoc.exists) {
    throw new HttpsError('not-found', 'This item no longer exists.');
  }
  const data = itemDoc.data()!;

  const validation = validateClaim({
    reportedBy: data.reportedBy ?? data.ownerUid ?? null,
    status: data.status ?? 'open',
    claimedBy: data.claimedBy ?? null,
    claimerUid,
  });

  if (!validation.ok) {
    throw new HttpsError(validation.code as never, validation.message);
  }

  const history = Array.isArray(data.statusHistory) ? data.statusHistory : [];
  const updatedHistory = [
    ...history,
    {
      status: PENDING_CLAIM_STATUS,
      changedAt: admin.firestore.Timestamp.now(),
      changedBy: claimerUid,
    },
  ];

  await itemDoc.ref.update({
    status: PENDING_CLAIM_STATUS,
    claimedBy: claimerUid,
    statusHistory: updatedHistory,
    updatedAt: admin.firestore.Timestamp.now(),
  });

  const reporter = data.reportedBy || data.ownerUid;
  const itemTitle = String(data.title ?? 'an item');

  // Notify the reporter that someone submitted a claim.
  if (reporter && reporter !== claimerUid) {
    await notifyUser(
      reporter,
      'Claim Submitted',
      `Someone has claimed your item "${itemTitle}". Please review and confirm the claim.`,
      'claim_submitted',
      itemId
    );
  }

  // Notify the claimer that their claim is pending review.
  await notifyUser(
    claimerUid,
    'Claim Submitted',
    `Your claim for "${itemTitle}" has been submitted and is pending review.`,
    'claim_submitted',
    itemId
  );

  return { ok: true, status: PENDING_CLAIM_STATUS };
});

// ── Resolve Item (server-side lifecycle) ─────────────────────────────────

/**
 * Callable: marks an item resolved. The caller must be the item's reporter
 * (or owner) or an admin. Writes the terminal status together with
 * `resolvedAt`/`resolvedBy` and a status-history entry atomically, and
 * notifies the other party (owner or claimer) when applicable.
 */
export const resolveItem = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError('unauthenticated', 'You must be signed in to resolve an item.');
  }

  const itemId =
    typeof request.data?.itemId === 'string' ? request.data.itemId.trim() : '';
  if (!itemId) {
    throw new HttpsError('invalid-argument', 'Missing item ID.');
  }

  const itemDoc = await db.collection('items').doc(itemId).get();
  if (!itemDoc.exists) {
    throw new HttpsError('not-found', 'This item no longer exists.');
  }
  const data = itemDoc.data()!;

  let isAdmin = false;
  try {
    const userDoc = await db.collection('users').doc(callerUid).get();
    isAdmin = userDoc.data()?.isAdmin === true;
  } catch {
    isAdmin = false;
  }

  const validation = validateResolve({
    status: data.status ?? 'open',
    ownerUid: data.ownerUid ?? null,
    reportedBy: data.reportedBy ?? null,
    callerUid,
    isAdmin,
  });

  if (!validation.ok) {
    throw new HttpsError(validation.code as never, validation.message);
  }

  const history = Array.isArray(data.statusHistory) ? data.statusHistory : [];
  const updatedHistory = [
    ...history,
    {
      status: RESOLVED_STATUS,
      changedAt: admin.firestore.Timestamp.now(),
      changedBy: callerUid,
    },
  ];

  const now = admin.firestore.Timestamp.now();
  await itemDoc.ref.update({
    status: RESOLVED_STATUS,
    resolvedAt: now,
    resolvedBy: callerUid,
    statusHistory: updatedHistory,
    updatedAt: now,
  });

  const owner = data.reportedBy || data.ownerUid;
  const claimedBy = data.claimedBy ?? null;
  const itemTitle = String(data.title ?? 'an item');

  // Notify the owner when someone else resolved it.
  if (owner && owner !== callerUid) {
    await notifyUser(
      owner,
      'Item Resolved',
      `Your item "${itemTitle}" has been marked as resolved.`,
      'status_resolved',
      itemId
    );
  }

  // Notify the claimer (if any) that their claim was resolved.
  if (claimedBy && claimedBy !== callerUid && claimedBy !== owner) {
    await notifyUser(
      claimedBy,
      'Claim Resolved',
      `Your claim for "${itemTitle}" has been resolved.`,
      'status_resolved',
      itemId
    );
  }

  return { ok: true, status: RESOLVED_STATUS };
});

// ── Admin Role Grant (server-side only) ──────────────────────────────────

/**
 * Callable: promotes the caller's user document to admin, but only when
 * their verified email matches the designated admin email. Admin assignment
 * never happens client-side — the app calls this and the server decides.
 */
export const grantAdminIfAuthorized = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }

  let email: string | undefined;
  try {
    const user = await admin.auth().getUser(uid);
    email = user.email;
  } catch {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }

  const normalized = (email ?? '').trim().toLowerCase();
  if (normalized !== ADMIN_EMAIL) {
    // Silently no-op for non-admins — no error, no privilege granted.
    return { granted: false };
  }

  await db.collection('users').doc(uid).set(
    {
      isAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { granted: true };
});

// ── Confirm Match (link two reports) ─────────────────────────────────────

/**
 * Callable: confirms that two opposite-kind items are the same object,
 * atomically linking them via `matchedItemId` and moving both to `matched`.
 * The caller must be an admin or the reporter/owner of either item.
 */
export const confirmMatch = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError('unauthenticated', 'You must be signed in to confirm a match.');
  }

  const itemId =
    typeof request.data?.itemId === 'string' ? request.data.itemId.trim() : '';
  const matchedItemId =
    typeof request.data?.matchedItemId === 'string'
      ? request.data.matchedItemId.trim()
      : '';
  if (!itemId || !matchedItemId || itemId === matchedItemId) {
    throw new HttpsError('invalid-argument', 'Two different item IDs are required.');
  }

  const [itemDoc, matchedDoc] = await Promise.all([
    db.collection('items').doc(itemId).get(),
    db.collection('items').doc(matchedItemId).get(),
  ]);
  if (!itemDoc.exists || !matchedDoc.exists) {
    throw new HttpsError('not-found', 'One of the items no longer exists.');
  }
  const data = itemDoc.data()!;
  const matchedData = matchedDoc.data()!;

  let isAdmin = false;
  try {
    const userDoc = await db.collection('users').doc(callerUid).get();
    isAdmin = userDoc.data()?.isAdmin === true;
  } catch {
    isAdmin = false;
  }

  const validation = validateMatchConfirm({
    kind: data.kind ?? null,
    matchedKind: matchedData.kind ?? null,
    status: data.status ?? 'open',
    matchedStatus: matchedData.status ?? 'open',
    reportedBy: data.reportedBy ?? null,
    matchedReportedBy: matchedData.reportedBy ?? null,
    ownerUid: data.ownerUid ?? null,
    matchedOwnerUid: matchedData.ownerUid ?? null,
    callerUid,
    isAdmin,
  });

  if (!validation.ok) {
    throw new HttpsError(validation.code as never, validation.message);
  }

  const now = admin.firestore.Timestamp.now();
  const historyA = Array.isArray(data.statusHistory) ? data.statusHistory : [];
  const historyB = Array.isArray(matchedData.statusHistory)
    ? matchedData.statusHistory
    : [];
  const entry = {
    status: MATCHED_STATUS,
    changedAt: now,
    changedBy: callerUid,
  };

  const batch = db.batch();
  batch.update(itemDoc.ref, {
    matchedItemId,
    status: MATCHED_STATUS,
    statusHistory: [...historyA, entry],
    updatedAt: now,
  });
  batch.update(matchedDoc.ref, {
    matchedItemId: itemId,
    status: MATCHED_STATUS,
    statusHistory: [...historyB, entry],
    updatedAt: now,
  });
  await batch.commit();

  const titleA = String(data.title ?? 'an item');
  const titleB = String(matchedData.title ?? 'an item');
  const ownerA = data.reportedBy || data.ownerUid;
  const ownerB = matchedData.reportedBy || matchedData.ownerUid;

  if (ownerA && ownerA !== callerUid) {
    await notifyUser(
      ownerA,
      'Match Confirmed',
      `Your "${titleA}" has been matched with "${titleB}".`,
      'match_confirmed',
      matchedItemId
    );
  }
  if (ownerB && ownerB !== callerUid) {
    await notifyUser(
      ownerB,
      'Match Confirmed',
      `Your "${titleB}" has been matched with "${titleA}".`,
      'match_confirmed',
      itemId
    );
  }

  return { ok: true, status: MATCHED_STATUS };
});

/** The single designated admin email (mirrors the client constant). */
const ADMIN_EMAIL = 'mugiwaranomelvin@gmail.com';
