import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:amongapp/data/firestore/claim_repository.dart';
import 'package:amongapp/models/claim_record.dart'
import 'package:amongapp/models/claim_page.dart';
import 'package:amongapp/models/user_profile.dart';
import 'package:amongapp/screens/admin_claimed_screen.dart';
import 'package:amongapp/services/auth_service.dart';

void main() {
  Provider.debugCheckInvalidValueType = null;
}

ClaimRecord _record({
  String id = 'claim-1',
  String title = 'Black Tumbler',
  String category = 'Electronics',
  List<String> imageUrls = const [],
  String? verificationPhotoUrl,
  String claimDate = 'Oct 5, 2026',
  String claimTime = '2:30 PM',
  String claimerName = 'Ana Cruz',
  String claimerEmail = 'ana@example.com',
  String reporterName = 'Ben Santos',
  String reporterEmail = 'ben@example.com',
  String pickupLocation = 'Library front desk',
  String kind = 'found',
}) {
  return ClaimRecord(
    id: id,
    itemId: id,
    itemTitle: title,
    category: category,
    description: 'Found near the entrance',
    imageUrls: imageUrls,
    verificationPhotoUrl: verificationPhotoUrl,
    claimDate: claimDate,
    claimTime: claimTime,
    claimerName: claimerName,
    claimerEmail: claimerEmail,
    reporterName: reporterName,
    reporterEmail: reporterEmail,
    pickupLocation: pickupLocation,
    kind: kind,
    status: ClaimRecordStatus.claimed,
    claimedAt: DateTime(2026, 10, 1, 14, 30),
  );
}

class _FakeClaimedPages {
  final List<String?> watchedCategories = <String?>[];
  final List<Object?> cursors = <Object?>[];

  Stream<ClaimPage> firstPage = const Stream.empty();
  ClaimPage nextPage = ClaimPage.empty;

  /// When set, [watch] emits this error instead of a page.
  Object? watchError;

  Stream<ClaimPage> watch({String? category, int limit = 20}) {
    watchedCategories.add(category);
    if (watchError != null) return Stream<ClaimPage>.error(watchError!);
    return firstPage;
  }

  Future<ClaimPage> more({
    String? category,
    int limit = 20,
    Object? cursor,
  }) async {
    watchedCategories.add(category);
    cursors.add(cursor);
    return nextPage;
  }
}

/// A fake AuthService that reports the user as an admin.
class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  User? get currentUser => throw UnimplementedError();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isAdminAuthenticated => true;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    return const AuthSuccess();
  }

  @override
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return const AuthSuccess();
  }

  @override
  Future<void> resendSignupOtp(String email) async {}

  @override
  Future<void> verifyEmailOtp({required String email, required String otp}) async {}

  @override
  Future<void> sendPasswordResetOtp(String email) async {}

  @override
  Future<void> verifyPasswordResetOtp({required String email, required String otp}) async {}

  @override
  Future<void> sendChangePasswordOtp(String email) async {}

  @override
  Future<void> verifyChangePasswordOtp({required String email, required String otp}) async {}

  @override
  Future<void> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<void> verifyPasswordResetOtp({required String email, required String otp}) async {}

  @override
  Future<void> verifyEmailOtp({required String email, required String otp}) async {}

  @override
  Future<void> refreshAdminStatus() async {}
}

Future<void> _pump(WidgetTester tester, _FakeClaimedPages fake) {
  return tester.pumpWidget(
    MaterialApp(
      home: Provider<AuthService>.value(
        value: _FakeAuthService(),
        child: AdminClaimedScreen(
          adminUid: 'admin-1',
          watchPage: fake.watch,
          morePage: fake.more,
        ),
      ),
    ),
  );
}

void main() {
  Provider.debugCheckInvalidValueType = null;
  runTests();
}

void runTests() {
  group('Admin Claimed Screen Tests', () {
    Future<void> _pump(WidgetTester tester, _FakeClaimedPages fake) {
      return tester.pumpWidget(
        MaterialApp(
          home: Provider<AuthService>.value(
            value: _FakeAuthService(),
            child: AdminClaimedScreen(
              adminUid: 'admin-1',
              watchPage: fake.watch,
              morePage: fake.more,
            ),
          ),
        ),
      );
    }

    testWidgets('shows a spinner while the first page loads', (tester) async {
      final fake = _FakeClaimedPages()
        ..firstPage = const Stream<ClaimPage>.empty();

      await _pump(tester, fake);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty page explains that nothing is claimed yet', (
      tester,
    ) async {
      final fake = _FakeClaimedPages()
        ..firstPage = Stream<ClaimPage>.value(ClaimPage.empty);

      await _pump(tester, fake);
      await tester.pumpAndSettle();

      expect(find.text('No claimed items yet'), findsOneWidget);
      expect(
        find.text('Handovers you complete will appear here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders every field the brief asks a claimed card to show', (
      tester,
    ) async {
      final fake = _FakeClaimedPages()
        ..firstPage = Stream<ClaimPage>.value(
          ClaimPage(
            records: [
              _record(
                imageUrls: const [
                  'https://example.invalid/1.jpg',
                  'https://example.invalid/2.jpg',
                ],
                verificationPhotoUrl: 'https://example.invalid/verify.jpg',
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );

      await _pump(tester, fake);
      await tester.pumpAndSettle();

      expect(find.text('Black Tumbler'), findsOneWidget);
      // Once in the chip row, once on the card.
      expect(find.text('Electronics'), findsWidgets);
      expect(find.text('Found near the entrance'), findsOneWidget);
      expect(find.text('Verification photo'), findsOneWidget);
      expect(find.text('Claim date'), findsOneWidget);
      expect(find.text('Oct 5, 2026'), findsOneWidget);
      expect(find.text('Claim time'), findsOneWidget);
      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.text('Pickup location'), findsOneWidget);
      expect(find.text('Library front desk'), findsOneWidget);
      expect(find.text('Claimer'), findsOneWidget);
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(find.text('Reporter'), findsOneWidget);
      expect(find.text('Ben Santos'), findsOneWidget);
      expect(find.text('ben@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a claimed card with no photos never throws', (tester) async {
      final fake = _FakeClaimedPages()
        ..firstPage = Stream<ClaimPage>.value(
          ClaimPage(records: [_record()], cursor: null, hasMore: false),
        );

      await _pump(tester, fake);
      await tester.pumpAndSettle();

      expect(find.byType(ClaimedCard), findsOneWidget);
      expect(find.text('Verification photo'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Load more pages through the cursor and appends rows', (
      tester,
    ) async {
      // A claimed card is tall; give the test a taller surface so the footer
      // below it exists without scrolling first.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _FakeClaimedPages()
        ..firstPage = Stream<ClaimPage>.value(
          ClaimPage(
            records: [_record(id: 'claim-1', title: 'First')],
            cursor: 'cursor-1',
            hasMore: true,
          ),
        )
        ..nextPage = ClaimPage(
          records: [
            _record(
              id: 'claim-2',
              title: 'Second',
              claimerName: 'Cara Diaz',
              claimerEmail: 'cara@example.com',
            ),
          ],
          cursor: 'cursor-2',
          hasMore: false,
        );

      await _pump(tester, fake);
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsOneWidget);
      expect(fake.cursors, ['cursor-1']);
      // Page 2 came back short: the button must disappear, not loop forever.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('Load more failure is friendly and retryable', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var failNext = true;
      Future<ClaimPage> more({
        String? category,
        int limit = 20,
        Object? cursor,
      }) async {
        if (failNext) {
          failNext = false;
          throw StateError('socket closed');
        }
        return const ClaimPage(records: [], cursor: null, hasMore: false);
      }

      final fake = _FakeClaimedPages()
        ..firstPage = Stream<ClaimPage>.value(
          ClaimPage(records: [_record()], cursor: 'cursor-1', hasMore: true),
        );

      await _pump(tester, fake);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      // Technical detail in the debug log, nothing raw on screen.
      expect(
        find.text('Could not load more claims. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('socket closed'), findsNothing);
      expect(tester.takeException(), isNull);

      // The retry works: the second attempt succeeds and the error clears.
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load more claims. Check your connection.'),
        findsNothing,
      );
    });
  }
}