'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  validateClaim,
  validateResolve,
  validateMatchConfirm,
  PENDING_CLAIM_STATUS,
  RESOLVED_STATUS,
  MATCHED_STATUS,
} = require('../lib/claims');

test('another user can successfully claim an open item', () => {
  const result = validateClaim({
    reportedBy: 'user-reporter',
    status: 'open',
    claimedBy: null,
    claimerUid: 'user-claimer',
  });
  assert.deepEqual(result, { ok: true });
});

test('the reporter is blocked from claiming their own item', () => {
  const result = validateClaim({
    reportedBy: 'user-reporter',
    status: 'open',
    claimedBy: null,
    claimerUid: 'user-reporter',
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'permission-denied');
  assert.equal(
    result.message,
    'You cannot claim an item you reported yourself.'
  );
});

test('blocked even when reportedBy falls back to ownerUid', () => {
  // Mirrors the callable: reportedBy ?? ownerUid.
  const result = validateClaim({
    reportedBy: 'owner-uid',
    status: 'verified',
    claimedBy: null,
    claimerUid: 'owner-uid',
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'permission-denied');
});

test('a claim is rejected once the item is terminal', () => {
  for (const status of ['claimed', 'resolved', 'closed']) {
    const result = validateClaim({
      reportedBy: 'user-reporter',
      status,
      claimedBy: null,
      claimerUid: 'user-claimer',
    });
    assert.equal(result.ok, false, `expected rejection for status ${status}`);
    assert.equal(result.code, 'failed-precondition');
    assert.equal(result.message, 'This item is no longer open for claims.');
  }
});

test('a claim is rejected when the item was already claimed', () => {
  const result = validateClaim({
    reportedBy: 'user-reporter',
    status: 'pendingClaim',
    claimedBy: 'user-claimer-1',
    claimerUid: 'user-claimer-2',
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'already-exists');
  assert.equal(result.message, 'This item has already been claimed.');
});

test('signed-out callers are rejected', () => {
  const result = validateClaim({
    reportedBy: 'user-reporter',
    status: 'open',
    claimedBy: null,
    claimerUid: '',
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'unauthenticated');
});

test('a user can claim an item when reportedBy is missing but they are not the owner', () => {
  const result = validateClaim({
    reportedBy: null,
    status: 'open',
    claimedBy: null,
    claimerUid: 'user-claimer',
  });
  assert.deepEqual(result, { ok: true });
});

test('pendingClaim status constant is exported for the callable', () => {
  assert.equal(PENDING_CLAIM_STATUS, 'pendingClaim');
});

test('the owner/reporter cannot resolve their own item', () => {
  const result = validateResolve({
    status: 'open',
    ownerUid: 'reporter-uid',
    reportedBy: 'reporter-uid',
    callerUid: 'reporter-uid',
    isAdmin: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'permission-denied');
});

test('an admin can resolve any item', () => {
  const result = validateResolve({
    status: 'pendingClaim',
    ownerUid: 'reporter-uid',
    reportedBy: 'reporter-uid',
    callerUid: 'admin-uid',
    isAdmin: true,
  });
  assert.deepEqual(result, { ok: true });
});

test('a non-admin cannot resolve an item', () => {
  const result = validateResolve({
    status: 'open',
    ownerUid: 'reporter-uid',
    reportedBy: 'reporter-uid',
    callerUid: 'stranger-uid',
    isAdmin: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'permission-denied');
  assert.equal(
    result.message,
    'Only an administrator can resolve an item.'
  );
});

test('terminal items cannot be resolved again', () => {
  for (const status of ['claimed', 'resolved', 'closed']) {
    const result = validateResolve({
      status,
      ownerUid: 'reporter-uid',
      reportedBy: 'reporter-uid',
      callerUid: 'admin-uid',
      isAdmin: true,
    });
    assert.equal(result.ok, false, `expected rejection for ${status}`);
    assert.equal(result.code, 'failed-precondition');
  }
});

test('signed-out callers cannot resolve', () => {
  const result = validateResolve({
    status: 'open',
    callerUid: '',
    isAdmin: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'unauthenticated');
});

test('resolve status constant is the terminal resolved status', () => {
  assert.equal(RESOLVED_STATUS, 'resolved');
});

test('a reporter can confirm a match between their item and an opposite-kind item', () => {
  const result = validateMatchConfirm({
    kind: 'lost',
    matchedKind: 'found',
    status: 'open',
    matchedStatus: 'open',
    reportedBy: 'user-a',
    matchedReportedBy: 'user-b',
    callerUid: 'user-a',
    isAdmin: false,
  });
  assert.deepEqual(result, { ok: true });
});

test('an admin can confirm a match between any two items', () => {
  const result = validateMatchConfirm({
    kind: 'lost',
    matchedKind: 'found',
    status: 'verified',
    matchedStatus: 'open',
    reportedBy: 'user-a',
    matchedReportedBy: 'user-b',
    callerUid: 'admin-uid',
    isAdmin: true,
  });
  assert.deepEqual(result, { ok: true });
});

test('a stranger cannot confirm a match they are not part of', () => {
  const result = validateMatchConfirm({
    kind: 'lost',
    matchedKind: 'found',
    status: 'open',
    matchedStatus: 'open',
    reportedBy: 'user-a',
    matchedReportedBy: 'user-b',
    callerUid: 'stranger',
    isAdmin: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'permission-denied');
});

test('same-kind items cannot be matched', () => {
  const result = validateMatchConfirm({
    kind: 'lost',
    matchedKind: 'lost',
    status: 'open',
    matchedStatus: 'open',
    reportedBy: 'user-a',
    matchedReportedBy: 'user-b',
    callerUid: 'user-a',
    isAdmin: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'invalid-argument');
});

test('terminal items cannot be matched', () => {
  const result = validateMatchConfirm({
    kind: 'lost',
    matchedKind: 'found',
    status: 'resolved',
    matchedStatus: 'open',
    reportedBy: 'user-a',
    matchedReportedBy: 'user-b',
    callerUid: 'user-a',
    isAdmin: false,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'failed-precondition');
});

test('match status constant is the matched status', () => {
  assert.equal(MATCHED_STATUS, 'matched');
});
