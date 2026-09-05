/**
 * Smart description matching for lost & found items.
 *
 * Pure module — no Firebase imports — so it can be unit-tested directly
 * against the compiled output (`node --test test/`).
 *
 * Scoring (0–100):
 *   - description (60%): character-trigram Jaccard similarity
 *   - category     (20%): exact (case-insensitive) match
 *   - location     (10%): exact (case-insensitive) match
 *   - date         (10%): proximity of report dates (decays 100 → 0 over 30 days)
 */

/** Lightweight shape of an item the matcher understands (avoids admin SDK deps). */
export interface MatchableItem {
  id: string;
  kind: 'lost' | 'found';
  title: string;
  description: string;
  category?: string | null;
  location?: string | null;
  createdAt?: Date | null;
  status: string;
  moderationStatus: string;
  reportedBy?: string | null;
  ownerUid?: string | null;
}

/** A persisted match candidate entry stored on the item document. */
export interface MatchScoreEntry {
  itemId: string;
  title: string;
  kind: 'lost' | 'found';
  score: number;
  matchedAt: Date;
}

/** Normalizes text for comparison: lowercase, strip punctuation, collapse spaces. */
export function normalizeText(text: string): string {
  return (text ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Character-trigram set of a normalized string (with edge padding).
 * Trigram overlap is robust to word inflection and ordering, which suits
 * short free-text descriptions written by different people.
 */
export function trigramSet(text: string): Set<string> {
  const t = normalizeText(text);
  if (t.length === 0) return new Set();
  if (t.length === 1) return new Set([`__${t}_`, `_${t}__`]);

  const trigrams = new Set<string>();
  // Pad with underscores so short strings still produce overlapping trigrams.
  const padded = `__${t}__`;
  for (let i = 0; i + 3 <= padded.length; i++) {
    trigrams.add(padded.slice(i, i + 3));
  }
  return trigrams;
}

/** Jaccard similarity of two sets: |A ∩ B| / |A ∪ B| (0..1). */
export function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const item of a) {
    if (b.has(item)) intersection++;
  }
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/** Description similarity (0..1) via trigram Jaccard. */
export function descriptionSimilarity(a: string, b: string): number {
  return jaccard(trigramSet(a), trigramSet(b));
}

/** Category similarity (0..1): exact case-insensitive match. */
export function categorySimilarity(
  a?: string | null,
  b?: string | null
): number {
  if (!a || !b) return 0;
  return a.trim().toLowerCase() === b.trim().toLowerCase() ? 1 : 0;
}

/** Location similarity (0..1): exact case-insensitive match. */
export function locationSimilarity(
  a?: string | null,
  b?: string | null
): number {
  if (!a || !b) return 0;
  return normalizeText(a) === normalizeText(b) ? 1 : 0;
}

/**
 * Date proximity (0..1): reports within 3 days score 1, decaying linearly
 * to 0 at 30 days apart.
 */
export function dateProximity(a?: Date | null, b?: Date | null): number {
  if (!a || !b) return 0;
  const days = Math.abs(a.getTime() - b.getTime()) / (24 * 60 * 60 * 1000);
  if (days <= 3) return 1;
  if (days >= 30) return 0;
  return 1 - (days - 3) / 27;
}

/**
 * Weighted match score between two items (0–100).
 * Description is the primary factor; category, location and date refine it.
 */
export function computeMatchScore(
  a: MatchableItem,
  b: MatchableItem
): number {
  const weights = {
    description: 0.6,
    category: 0.2,
    location: 0.1,
    date: 0.1,
  };

  const score =
    descriptionSimilarity(a.description, b.description) * weights.description +
    categorySimilarity(a.category, b.category) * weights.category +
    locationSimilarity(a.location, b.location) * weights.location +
    dateProximity(a.createdAt, b.createdAt) * weights.date;

  return Math.round(score * 100);
}

/**
 * Filters scored candidates to those at/above [threshold], sorts by score
 * descending (ties broken by newest first) and caps at [max] entries.
 */
export function selectMatches(
  scored: MatchScoreEntry[],
  options: { threshold: number; max: number }
): MatchScoreEntry[] {
  return scored
    .filter((entry) => entry.score >= options.threshold)
    .sort(
      (x, y) =>
        y.score - x.score ||
        (y.matchedAt?.getTime() ?? 0) - (x.matchedAt?.getTime() ?? 0)
    )
    .slice(0, options.max);
}

/** Defaults used by the app. */
export const MATCH_THRESHOLD = 70;
export const MAX_STORED_MATCHES = 10;