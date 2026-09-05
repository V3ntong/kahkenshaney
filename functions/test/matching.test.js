'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeText,
  descriptionSimilarity,
  categorySimilarity,
  locationSimilarity,
  dateProximity,
  computeMatchScore,
  selectMatches,
  MATCH_THRESHOLD,
  MAX_STORED_MATCHES,
} = require('../lib/matching');

function item(overrides = {}) {
  return {
    id: 'item-a',
    kind: 'lost',
    title: 'Black Tumbler',
    description: 'Black insulated tumbler with a scratch on the lid',
    category: 'Drinkware',
    location: 'Library Level 2',
    createdAt: new Date('2026-09-01T10:00:00Z'),
    status: 'open',
    moderationStatus: 'approved',
    reportedBy: 'user-a',
    ...overrides,
  };
}

test('normalizeText lowercases and strips punctuation', () => {
  assert.equal(normalizeText('  Black Tumbler!!! '), 'black tumbler');
  assert.equal(normalizeText(''), '');
});

test('descriptionSimilarity is high for near-identical text', () => {
  const a = 'Black insulated tumbler with a scratch on the lid';
  const b = 'Black insulated tumbler with a scratch on the lid';
  assert.ok(descriptionSimilarity(a, b) >= 0.9);
});

test('descriptionSimilarity is low for unrelated text', () => {
  const a = 'Black insulated tumbler with a scratch on the lid';
  const b = 'Red laptop charger cable for gaming computer';
  assert.ok(descriptionSimilarity(a, b) < 0.3);
});

test('computeMatchScore: identical items score ~100', () => {
  const base = item();
  const other = item({ id: 'item-b', kind: 'found', reportedBy: 'user-b' });
  assert.ok(computeMatchScore(base, other) >= 95);
});

test('computeMatchScore: same category and location boost an unrelated description', () => {
  const base = item();
  const other = item({
    id: 'item-b',
    kind: 'found',
    reportedBy: 'user-b',
    description: 'completely different words here nothing alike',
  });
  const withCategoryLocation = computeMatchScore(base, other);
  // Category (20%) + location (10%) exact matches → at least 30.
  assert.ok(withCategoryLocation >= 30);
  assert.ok(withCategoryLocation < 45);
});

test('computeMatchScore: unrelated everything scores near zero', () => {
  const base = item();
  const other = item({
    id: 'item-b',
    kind: 'found',
    reportedBy: 'user-b',
    description: 'completely different words here nothing alike',
    category: 'Electronics',
    location: 'Main Gate',
    createdAt: new Date('2026-01-01T10:00:00Z'),
  });
  assert.ok(computeMatchScore(base, other) < 15);
});

test('dateProximity decays from 1 to 0 over 30 days', () => {
  const now = new Date('2026-09-01T10:00:00Z');
  assert.equal(dateProximity(now, new Date('2026-09-02T10:00:00Z')), 1);
  assert.ok(dateProximity(now, new Date('2026-09-16T10:00:00Z')) > 0.3);
  assert.ok(dateProximity(now, new Date('2026-09-16T10:00:00Z')) < 0.7);
  assert.equal(dateProximity(now, new Date('2026-10-15T10:00:00Z')), 0);
});

test('categorySimilarity and locationSimilarity are case-insensitive', () => {
  assert.equal(categorySimilarity('Drinkware', 'drinkware'), 1);
  assert.equal(categorySimilarity('Drinkware', 'Electronics'), 0);
  assert.equal(locationSimilarity('Library Level 2', 'library level 2'), 1);
  assert.equal(locationSimilarity('Library Level 2', 'Main Gate'), 0);
});

test('selectMatches filters below threshold and sorts by score desc', () => {
  const scored = [
    { itemId: 'c', title: 'C', kind: 'lost', score: 40, matchedAt: new Date() },
    { itemId: 'a', title: 'A', kind: 'lost', score: 95, matchedAt: new Date() },
    { itemId: 'b', title: 'B', kind: 'lost', score: 71, matchedAt: new Date() },
  ];
  const selected = selectMatches(scored, { threshold: 70, max: 10 });
  assert.deepEqual(
    selected.map((s) => s.itemId),
    ['a', 'b']
  );
});

test('selectMatches caps results at max', () => {
  const scored = Array.from({ length: 20 }, (_, i) => ({
    itemId: `item-${i}`,
    title: `Item ${i}`,
    kind: 'lost',
    score: 100,
    matchedAt: new Date(),
  }));
  const selected = selectMatches(scored, { threshold: 0, max: 5 });
  assert.equal(selected.length, 5);
});

test('defaults: threshold is 70 and max stored matches is 10', () => {
  assert.equal(MATCH_THRESHOLD, 70);
  assert.equal(MAX_STORED_MATCHES, 10);
});