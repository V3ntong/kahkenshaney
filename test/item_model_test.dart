import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/models/lost_found_item.dart';

LostFoundItem _baseItem({
  String reportedBy = 'user-reporter',
  String? claimedBy,
  ItemStatus status = ItemStatus.open,
  List<ItemMatchScore> matchScores = const [],
}) {
  return LostFoundItem(
    id: 'item-1',
    kind: ItemKind.lost,
    title: 'Black Tumbler',
    description: 'Black insulated tumbler with a scratch on the lid',
    ownerUid: reportedBy,
    reportedBy: reportedBy,
    claimedBy: claimedBy,
    status: status,
    matchScores: matchScores,
    category: 'Drinkware',
    location: 'Library Level 2',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}

void main() {
  group('reportedBy', () {
    test('round-trips through fromMap/toMap', () {
      final item = _baseItem();
      final restored = LostFoundItem.fromMap(item.id, item.toMap());
      expect(restored.reportedBy, 'user-reporter');
      expect(restored.ownerUid, 'user-reporter');
    });

    test('defaults to empty when missing from Firestore', () {
      final map = _baseItem().toMap()..remove('reportedBy');
      final restored = LostFoundItem.fromMap('item-1', map);
      expect(restored.reportedBy, '');
    });
  });

  group('ItemMatchScore', () {
    test('round-trips through fromMap/toMap', () {
      final score = ItemMatchScore(
        itemId: 'item-2',
        title: 'Black tumbler found in library',
        kind: ItemKind.found,
        score: 87,
        matchedAt: DateTime(2026, 9, 2),
      );
      final restored = ItemMatchScore.fromMap(score.toMap());
      expect(restored.itemId, 'item-2');
      expect(restored.title, 'Black tumbler found in library');
      expect(restored.kind, ItemKind.found);
      expect(restored.score, 87);
      expect(restored.matchedAt, DateTime(2026, 9, 2));
    });

    test('matchScores are persisted on the item and survive round-trip', () {
      final item = _baseItem(
        matchScores: const [
          ItemMatchScore(
            itemId: 'item-2',
            title: 'Black tumbler found in library',
            kind: ItemKind.found,
            score: 87,
          ),
          ItemMatchScore(
            itemId: 'item-3',
            title: 'Insulated bottle in cafeteria',
            kind: ItemKind.found,
            score: 72,
          ),
        ],
      );
      final restored = LostFoundItem.fromMap(item.id, item.toMap());
      expect(restored.matchScores, hasLength(2));
      expect(restored.matchScores.first.score, 87);
      expect(restored.matchScores.last.kind, ItemKind.found);
    });
  });

  group('pendingClaim status', () {
    test('has the expected firestore value and labels', () {
      expect(ItemStatus.pendingClaim.firestoreValue, 'pendingClaim');
      expect(ItemStatus.pendingClaim.label, 'Pending Claim');
      expect(ItemStatus.pendingClaim.shortLabel, 'Claim Pending');
    });

    test('is not terminal (a claim can still be confirmed or rejected)', () {
      expect(ItemStatus.pendingClaim.isTerminal, isFalse);
    });

    test('round-trips through fromMap', () {
      final restored = LostFoundItem.fromMap(
        'item-1',
        _baseItem(status: ItemStatus.pendingClaim).toMap(),
      );
      expect(restored.status, ItemStatus.pendingClaim);
    });
  });

  group('claimedBy', () {
    test('round-trips through fromMap/toMap', () {
      final restored = LostFoundItem.fromMap(
        'item-1',
        _baseItem(claimedBy: 'user-claimer').toMap(),
      );
      expect(restored.claimedBy, 'user-claimer');
    });
  });

  group('eventDate', () {
    test('round-trips through fromMap/toMap', () {
      final date = DateTime(2026, 8, 30);
      final item = LostFoundItem(
        id: 'item-1',
        kind: ItemKind.lost,
        title: 'Tumbler',
        description: 'Black',
        ownerUid: 'u1',
        reportedBy: 'u1',
        eventDate: date,
      );
      final restored = LostFoundItem.fromMap(item.id, item.toMap());
      expect(restored.eventDate, date);
    });

    test('defaults to null when missing from Firestore', () {
      final map = _baseItem().toMap()..remove('eventDate');
      final restored = LostFoundItem.fromMap('item-1', map);
      expect(restored.eventDate, isNull);
    });
  });

  group('canBeClaimedBy', () {
    test('another user can claim an open item', () {
      expect(_baseItem().canBeClaimedBy('user-claimer'), isTrue);
    });

    test('the reporter cannot claim their own item', () {
      expect(_baseItem().canBeClaimedBy('user-reporter'), isFalse);
    });

    test('the owner cannot claim even when reportedBy differs', () {
      final item = _baseItem(reportedBy: 'actual-reporter');
      // ownerUid still points at the reporter in this fixture, so simulate
      // an item where ownerUid is the current user.
      final owner = LostFoundItem(
        id: item.id,
        kind: item.kind,
        title: item.title,
        description: item.description,
        ownerUid: 'me',
        reportedBy: 'other',
      );
      expect(owner.canBeClaimedBy('me'), isFalse);
    });

    test('terminal items reject claims', () {
      for (final status in [
        ItemStatus.claimed,
        ItemStatus.resolved,
        ItemStatus.closed,
      ]) {
        expect(
          _baseItem(status: status).canBeClaimedBy('user-claimer'),
          isFalse,
          reason: 'expected rejection for $status',
        );
      }
    });

    test('an already-claimed item rejects new claims', () {
      final item = _baseItem(
        status: ItemStatus.pendingClaim,
        claimedBy: 'user-claimer-1',
      );
      expect(item.canBeClaimedBy('user-claimer-2'), isFalse);
    });

    test('admins and signed-out users cannot claim', () {
      expect(_baseItem().canBeClaimedBy('', isAdmin: false), isFalse);
      expect(_baseItem().canBeClaimedBy('user-claimer', isAdmin: true), isFalse);
    });

    test('copyWith preserves reportedBy and updates claimedBy', () {
      final item = _baseItem().copyWith(claimedBy: 'user-claimer');
      expect(item.reportedBy, 'user-reporter');
      expect(item.claimedBy, 'user-claimer');
    });
  });
}