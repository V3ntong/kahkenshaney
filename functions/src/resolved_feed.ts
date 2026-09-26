import * as admin from 'firebase-admin';

/**
 * Publishes a public entry for the homepage "Recently Resolved" feed
 * (`resolvedFeed/{itemId}`) when an item's claim is approved and the item
 * reaches a terminal status.
 *
 * Privacy rules enforced here (the feed is readable by every signed-in user):
 *  - Only items that are publicly visible (`moderationStatus == 'approved'`)
 *    are published.
 *  - Display names only — never email, phone, or user IDs.
 *  - Locations are the same fields already exposed on the public item
 *    document, so this adds no new PII exposure.
 *
 * Firestore rules deny all client writes to this collection; only this
 * server-side path (Admin SDK bypasses rules) can create entries.
 */
export async function publishResolvedFeedEntry(
  itemId: string,
  data: admin.firestore.DocumentData
): Promise<void> {
  if (data.moderationStatus !== 'approved') return;

  const finderUid =
    (typeof data.reportedBy === 'string' && data.reportedBy) ||
    (typeof data.ownerUid === 'string' && data.ownerUid) ||
    '';
  const claimerUid =
    typeof data.claimedBy === 'string' && data.claimedBy ? data.claimedBy : '';

  const [finderName, claimerName, claim] = await Promise.all([
    finderUid ? fetchDisplayName(finderUid) : Promise.resolve(null),
    claimerUid ? fetchDisplayName(claimerUid) : Promise.resolve(null),
    fetchApprovedClaim(itemId),
  ]);

  const media = Array.isArray(data.media) ? data.media : [];
  const now = admin.firestore.Timestamp.now();

  const entry: Record<string, unknown> = {
    itemId,
    title: String(data.title ?? ''),
    description: String(data.description ?? ''),
    kind: data.kind === 'lost' ? 'lost' : 'found',
    category: data.category ?? null,
    imageUrl:
      typeof data.imageUrl === 'string' && data.imageUrl
        ? data.imageUrl
        : media.length > 0 && typeof media[0] === 'string'
          ? media[0]
          : null,
    // Found date: the report's event date, else when it was reported.
    foundAt: data.eventDate ?? data.createdAt ?? null,
    foundLocation: typeof data.location === 'string' ? data.location : null,
    finderName,
    claimerName,
    claimAt: claimerUid ? (claim?.createdAt ?? data.resolvedAt ?? now) : null,
    claimLocation: claimerUid
      ? (claim?.location ??
        (typeof data.pickupLocation === 'string' ? data.pickupLocation : null))
      : null,
    resolvedAt: data.resolvedAt ?? now,
    publishedAt: now,
  };

  await admin
    .firestore()
    .collection('resolvedFeed')
    .doc(itemId)
    .set(entry, { merge: true });
}

/** Display name for a user doc — never email/phone. Returns null if absent. */
export async function fetchDisplayName(uid: string): Promise<string | null> {
  try {
    const snap = await admin.firestore().collection('users').doc(uid).get();
    const name = snap.data()?.displayName;
    return typeof name === 'string' && name.trim() ? name.trim() : null;
  } catch {
    return null;
  }
}

/**
 * The approved claim for an item (A4 subcollection) — used for the claim
 * date/location on the feed card. Returns null when no claim subcollection
 * exists yet (legacy single-claim data).
 */
async function fetchApprovedClaim(
  itemId: string
): Promise<{ createdAt: unknown; location: string | null } | null> {
  try {
    const snap = await admin
      .firestore()
      .collection('items')
      .doc(itemId)
      .collection('claims')
      .where('status', '==', 'approved')
      .limit(1)
      .get();
    if (snap.empty) return null;
    const claim = snap.docs[0].data();
    return {
      createdAt: claim.createdAt ?? null,
      location:
        typeof claim.location === 'string' && claim.location
          ? claim.location
          : null,
    };
  } catch {
    return null;
  }
}
