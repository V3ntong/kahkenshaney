/**
 * Claim validation for lost & found items.
 *
 * Pure module — no Firebase imports — so the server-side rules can be unit
 * tested directly against the compiled output (`node --test test/`).
 */

/** Terminal statuses: a claim can never be submitted against these. */
const TERMINAL_STATUSES = new Set(['claimed', 'resolved', 'closed']);

export interface ClaimContext {
  /** The UID that originally reported the item (`reportedBy` field). */
  reportedBy?: string | null;
  /** The item's current lifecycle status. */
  status?: string | null;
  /** The UID of whoever already claimed the item, if any. */
  claimedBy?: string | null;
  /** The signed-in user attempting the claim. */
  claimerUid?: string | null;
}

export type ClaimValidation =
  | { ok: true }
  | { ok: false; code: string; message: string };

/**
 * Server-side check for the "claim item" action.
 *
 * A user can never claim an item they reported themselves, and a claim is
 * rejected when the item is terminal or already claimed. This is enforced
 * here (the backend layer) so it cannot be bypassed with direct API calls.
 */
export function validateClaim(context: ClaimContext): ClaimValidation {
  const claimerUid = context.claimerUid ?? '';
  if (!claimerUid) {
    return {
      ok: false,
      code: 'unauthenticated',
      message: 'You must be signed in to claim an item.',
    };
  }

  if (context.reportedBy && context.reportedBy === claimerUid) {
    return {
      ok: false,
      code: 'permission-denied',
      message: 'You cannot claim an item you reported yourself.',
    };
  }

  if (context.status && TERMINAL_STATUSES.has(context.status)) {
    return {
      ok: false,
      code: 'failed-precondition',
      message: 'This item is no longer open for claims.',
    };
  }

  if (context.claimedBy) {
    return {
      ok: false,
      code: 'already-exists',
      message: 'This item has already been claimed.',
    };
  }

  return { ok: true };
}

/** The lifecycle status an item enters once a claim is submitted. */
export const PENDING_CLAIM_STATUS = 'pendingClaim';

// ── Resolution (resolveItem) ─────────────────────────────────────────────

export interface ResolveContext {
  /** The item's current lifecycle status. */
  status?: string | null;
  /** The UID that reported/owns the item. */
  ownerUid?: string | null;
  reportedBy?: string | null;
  /** The signed-in user attempting the resolution. */
  callerUid?: string | null;
  /** Whether the caller is an admin (resolved server-side). */
  isAdmin?: boolean;
}

export type ResolveValidation =
  | { ok: true }
  | { ok: false; code: string; message: string };

/**
 * Server-side check for the "resolve item" action: only an administrator may
 * resolve, and only while the item is open.
 */
export function validateResolve(context: ResolveContext): ResolveValidation {
  const callerUid = context.callerUid ?? '';
  if (!callerUid) {
    return {
      ok: false,
      code: 'unauthenticated',
      message: 'You must be signed in to resolve an item.',
    };
  }

  if (!context.isAdmin) {
    return {
      ok: false,
      code: 'permission-denied',
      message: 'Only an administrator can resolve an item.',
    };
  }

  if (context.status && TERMINAL_STATUSES.has(context.status)) {
    return {
      ok: false,
      code: 'failed-precondition',
      message: 'This item is already resolved.',
    };
  }

  return { ok: true };
}

/** The terminal lifecycle status written by [resolveItem]. */
export const RESOLVED_STATUS = 'resolved';

// ── Match confirmation (confirmMatch) ────────────────────────────────────

export interface MatchConfirmContext {
  /** Kind of the first item (`lost` | `found`). */
  kind?: string | null;
  /** Kind of the matched item. */
  matchedKind?: string | null;
  /** Lifecycle status of each item. */
  status?: string | null;
  matchedStatus?: string | null;
  /** Reporters/owners of each item. */
  reportedBy?: string | null;
  matchedReportedBy?: string | null;
  ownerUid?: string | null;
  matchedOwnerUid?: string | null;
  /** The signed-in caller. */
  callerUid?: string | null;
  /** Whether the caller is an admin. */
  isAdmin?: boolean;
}

export type MatchConfirmValidation =
  | { ok: true }
  | { ok: false; code: string; message: string };

/**
 * Server-side check for confirming a match between two opposite-kind items.
 * The caller must be an admin or the reporter/owner of either item, both
 * items must be open, and they must be opposite kinds (lost ↔ found).
 */
export function validateMatchConfirm(
  context: MatchConfirmContext
): MatchConfirmValidation {
  const callerUid = context.callerUid ?? '';
  if (!callerUid) {
    return {
      ok: false,
      code: 'unauthenticated',
      message: 'You must be signed in to confirm a match.',
    };
  }

  if (context.status && TERMINAL_STATUSES.has(context.status)) {
    return {
      ok: false,
      code: 'failed-precondition',
      message: 'This item is no longer open for matching.',
    };
  }
  if (
    context.matchedStatus &&
    TERMINAL_STATUSES.has(context.matchedStatus)
  ) {
    return {
      ok: false,
      code: 'failed-precondition',
      message: 'The matched item is no longer open.',
    };
  }

  if (!context.kind || !context.matchedKind || context.kind === context.matchedKind) {
    return {
      ok: false,
      code: 'invalid-argument',
      message: 'Only lost and found items can be matched together.',
    };
  }

  if (!context.isAdmin) {
    const ownersA = [context.reportedBy, context.ownerUid].filter(Boolean);
    const ownersB = [context.matchedReportedBy, context.matchedOwnerUid].filter(
      Boolean
    );
    const isOwnerOfEither =
      ownersA.includes(callerUid) || ownersB.includes(callerUid);
    if (!isOwnerOfEither) {
      return {
        ok: false,
        code: 'permission-denied',
        message: 'Only the item reporters or an admin can confirm a match.',
      };
    }
  }

  return { ok: true };
}

/** The lifecycle status both items enter once a match is confirmed. */
export const MATCHED_STATUS = 'matched';
