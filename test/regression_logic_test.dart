import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/data/firestore/support_chat_service.dart';
import 'package:amongapp/models/lost_found_item.dart';
import 'package:amongapp/services/admin_api.dart';
import 'package:amongapp/services/chat_service.dart';

LostFoundItem _item({
  String ownerUid = 'owner-1',
  String reportedBy = 'reporter-1',
  ItemStatus status = ItemStatus.open,
  ModerationStatus moderationStatus = ModerationStatus.pending,
  String? claimedBy,
}) {
  return LostFoundItem(
    id: 'item-1',
    kind: ItemKind.lost,
    title: 'Wallet',
    description: 'Brown leather wallet',
    ownerUid: ownerUid,
    reportedBy: reportedBy,
    status: status,
    moderationStatus: moderationStatus,
    claimedBy: claimedBy,
  );
}

void main() {
  // Regression: the peer-chat document ID must be canonical, otherwise two
  // users talking past each other create two different chat documents and
  // the Firestore rules that key off `participants` stop lining up with the
  // ID the client writes to.
  group('peer chat ID canonicalization', () {
    test('is symmetric — both orderings produce the same ID', () {
      expect(
        SupportChatService.peerChatId('alice', 'bob'),
        SupportChatService.peerChatId('bob', 'alice'),
      );
    });

    test('sorts UIDs alphabetically so the ID is deterministic', () {
      expect(SupportChatService.peerChatId('bob', 'alice'), 'peer_alice_bob');
      expect(SupportChatService.peerChatId('alice', 'bob'), 'peer_alice_bob');
    });

    test('uses the peer_{uidA}_{uidB} format the rules/queries expect', () {
      final id = SupportChatService.peerChatId('u2', 'u1');
      expect(id, 'peer_u1_u2');
      expect(RegExp(r'^peer_[^_]+_[^_]+$').hasMatch(id), isTrue);
    });

    test('distinct pairs yield distinct IDs', () {
      final ab = SupportChatService.peerChatId('alice', 'bob');
      final ac = SupportChatService.peerChatId('alice', 'carol');
      final bc = SupportChatService.peerChatId('bob', 'carol');
      expect({ab, ac, bc}, hasLength(3));
    });

    test('a UID with digits/uppercase still round-trips deterministically', () {
      const uidA = 'UserA123';
      const uidB = 'userB456';
      expect(
        SupportChatService.peerChatId(uidA, uidB),
        SupportChatService.peerChatId(uidB, uidA),
      );
      expect(SupportChatService.peerChatId(uidA, uidB), 'peer_UserA123_userB456');
    });
  });

  // Regression: status transitions decide claimability, review-queue buttons
  // and the resolved feed. A wrong terminal set previously let claims land on
  // resolved items.
  group('status transition logic', () {
    test('terminal statuses are exactly claimed, resolved and closed', () {
      final terminal =
          ItemStatus.values.where((s) => s.isTerminal).toList();
      expect(terminal, [ItemStatus.claimed, ItemStatus.resolved, ItemStatus.closed]);
    });

    test('pendingClaim is not terminal — it can still be confirmed/rejected', () {
      expect(ItemStatus.pendingClaim.isTerminal, isFalse);
      expect(ItemStatus.open.isTerminal, isFalse);
      expect(ItemStatus.pendingVerification.isTerminal, isFalse);
      expect(ItemStatus.verified.isTerminal, isFalse);
      expect(ItemStatus.matched.isTerminal, isFalse);
    });

    test('unknown or missing Firestore status falls back to open', () {
      expect(ItemStatusX.fromFirestore('bogus'), ItemStatus.open);
      expect(ItemStatusX.fromFirestore(null), ItemStatus.open);
      expect(ItemStatusX.fromFirestore('resolved'), ItemStatus.resolved);
    });

    test('public visibility requires approved moderation only', () {
      expect(_item(moderationStatus: ModerationStatus.approved).isPublic, isTrue);
      expect(_item(moderationStatus: ModerationStatus.pending).isPublic, isFalse);
      expect(_item(moderationStatus: ModerationStatus.rejected).isPublic, isFalse);
    });

    test('a terminal status blocks new claims even for other users', () {
      for (final status in [ItemStatus.claimed, ItemStatus.resolved, ItemStatus.closed]) {
        expect(
          _item(status: status).canBeClaimedBy('someone-else'),
          isFalse,
          reason: 'claim must be rejected for $status',
        );
      }
    });

    test('an open, unclaimed item is claimable by anyone but the reporter', () {
      final item = _item();
      expect(item.canBeClaimedBy('someone-else'), isTrue);
      expect(item.canBeClaimedBy('reporter-1'), isFalse);
      expect(item.canBeClaimedBy('owner-1'), isFalse);
    });
  });

  // Regression: the admin-invite flow previously broke on response parsing —
  // the client must tolerate missing/extra fields from the callables.
  group('admin invite response parsing', () {
    test('InviteResult.fromMap tolerates missing fields', () {
      final result = InviteResult.fromMap(const {});
      expect(result.inviteId, '');
      expect(result.resent, isFalse);
      expect(result.emailSent, isFalse);
    });

    test('InviteResult.fromMap reads a full payload', () {
      final result = InviteResult.fromMap(const {
        'inviteId': 'inv-1',
        'resent': true,
        'emailSent': true,
      });
      expect(result.inviteId, 'inv-1');
      expect(result.resent, isTrue);
      expect(result.emailSent, isTrue);
    });

    test('PendingInvite.fromMap parses ISO timestamps and ignores junk', () {
      final invite = PendingInvite.fromMap(const {
        'id': 'inv-1',
        'email': 'newadmin@example.com',
        'invitedByEmail': 'mugiwaranomelvin@gmail.com',
        'sentAt': '2026-09-01T10:00:00.000',
        'expiresAt': 'not-a-date',
      });
      expect(invite.id, 'inv-1');
      expect(invite.email, 'newadmin@example.com');
      expect(invite.sentAt, DateTime(2026, 9, 1, 10));
      expect(invite.expiresAt, isNull);
    });

    test('PendingInvite.fromMap survives a payload with only an email', () {
      final invite = PendingInvite.fromMap(const {'email': 'a@b.c'});
      expect(invite.email, 'a@b.c');
      expect(invite.id, '');
      expect(invite.sentAt, isNull);
      expect(invite.expiresAt, isNull);
    });

    test('non-Firebase errors map to the generic safe message', () {
      expect(AdminApi.messageFor(Exception('boom')),
          'Something went wrong. Please try again.');
    });
  });

  // Regression: the chatbot's `not-found` code (function not deployed) was
  // previously reported to users as an App Check verification failure.
  group('chatbot error mapping', () {
    test('not-found is NOT an App Check code', () {
      expect(ChatService.isAppCheckCode('not-found'), isFalse);
      expect(ChatService.isAppCheckCode('permission-denied'), isFalse);
      expect(ChatService.isAppCheckCode('unauthenticated'), isFalse);
    });

    test('real App Check codes are recognized', () {
      expect(ChatService.isAppCheckCode('app-check-unauthorized'), isTrue);
      expect(ChatService.isAppCheckCode('app-check-token-fetch-failed'), isTrue);
      expect(ChatService.isAppCheckCode('app-check-throttled'), isTrue);
    });

    test('not-found tells the user the service is missing, not app security', () {
      final message = ChatService.userFacingError('not-found');
      expect(message, contains('not available'));
      expect(message.toLowerCase(), isNot(contains('app security')));
    });

    test('every known code produces a distinct, non-empty message', () {
      const codes = [
        'unauthenticated',
        'permission-denied',
        'resource-exhausted',
        'deadline-exceeded',
        'unavailable',
        'failed-precondition',
        'invalid-argument',
        'not-found',
        'internal',
        'unknown-code',
      ];
      final messages = codes.map(ChatService.userFacingError).toSet();
      expect(messages.length, codes.length,
          reason: 'each code should map to its own user-facing message');
      for (final message in messages) {
        expect(message, isNotEmpty);
      }
    });
  });
}
