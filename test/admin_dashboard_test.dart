import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/data/firestore/admin_repository.dart';
import 'package:amongapp/models/lost_found_item.dart';
import 'package:amongapp/screens/admin_dashboard.dart';
import 'package:amongapp/services/auth_service.dart';
import 'package:amongapp/theme/app_theme.dart';

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository(this.items);

  final List<LostFoundItem> items;

  @override
  Stream<List<LostFoundItem>> streamAllItems() => Stream.value(items);

  @override
  Stream<int> streamUserCount() => Stream.value(3);
}

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isAdminAuthenticated => true;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return const AuthSuccess();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return const AuthFailure('Not implemented in test.');
  }

  @override
  Future<void> resendSignupOtp(String email) async {}

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {}

  @override
  Future<void> sendPasswordResetOtp(String email) async {}

  @override
  Future<void> sendChangePasswordOtp(String email) async {}

  @override
  Future<void> verifyChangePasswordOtp({
    required String email,
    required String otp,
  }) async {}

  @override
  Future<void> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<bool> refreshAdminStatus() async => true;
}

List<LostFoundItem> _sampleItems() {
  final now = DateTime.now();
  return [
    LostFoundItem(
      id: '1',
      kind: ItemKind.lost,
      title: 'iPhone 14',
      description: 'Black',
      ownerUid: 'u1',
      location: 'Library',
      status: ItemStatus.open,
      createdAt: now,
    ),
    LostFoundItem(
      id: '2',
      kind: ItemKind.lost,
      title: 'Wallet',
      description: 'Brown leather',
      ownerUid: 'u2',
      location: 'Main Gate',
      status: ItemStatus.open,
      createdAt: now,
    ),
    LostFoundItem(
      id: '3',
      kind: ItemKind.lost,
      title: 'ID Card',
      description: 'Blue',
      ownerUid: 'u3',
      location: 'Gym',
      status: ItemStatus.matched,
      createdAt: now,
    ),
    LostFoundItem(
      id: '4',
      kind: ItemKind.found,
      title: 'Keys',
      description: 'Set of 3',
      ownerUid: 'u4',
      status: ItemStatus.open,
      createdAt: now,
    ),
    LostFoundItem(
      id: '5',
      kind: ItemKind.found,
      title: 'Umbrella',
      description: 'Blue',
      ownerUid: 'u5',
      status: ItemStatus.matched,
      createdAt: now,
    ),
  ];
}

Widget _app({required Widget home}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: home,
  );
}

void main() {
  testWidgets('Admin dashboard renders overview sections with data',
      (tester) async {
    await tester.pumpWidget(
      _app(
        home: AdminDashboardScreen(
          authService: _FakeAuthService(),
          repository: _FakeAdminRepository(_sampleItems()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('Welcome back, Admin'), findsOneWidget);
    expect(find.text('total lost reports'), findsOneWidget);
    expect(find.text('total found reports'), findsOneWidget);
    expect(find.text('registered accounts'), findsOneWidget);
    expect(find.text('awaiting review'), findsOneWidget);
    expect(find.text('Reports Overview'), findsOneWidget);
    expect(find.text('Reports by Category'), findsOneWidget);
    expect(find.text('Recent Reports'), findsOneWidget);
    expect(find.text('Admin Actions'), findsOneWidget);
    expect(find.text('Technology Stack'), findsOneWidget);
    expect(find.text('iPhone 14'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('View'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin dashboard shows clean empty states without data',
      (tester) async {
    await tester.pumpWidget(
      _app(
        home: AdminDashboardScreen(
          authService: _FakeAuthService(),
          repository: _FakeAdminRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No reports submitted yet.'), findsOneWidget);
    expect(find.text('No report activity in the last 7 days yet.'),
        findsOneWidget);
    expect(find.text('No reports to categorize yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sidebar logout navigates back to the landing page',
      (tester) async {
    await tester.pumpWidget(
      _app(
        home: AdminDashboardScreen(
          authService: _FakeAuthService(),
          repository: _FakeAdminRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menuButton = find.byIcon(Icons.menu);
    expect(menuButton, findsOneWidget);

    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    final logout = find.widgetWithText(InkWell, 'Logout');
    expect(logout, findsOneWidget);

    await tester.tap(logout);
    await tester.pumpAndSettle();

    // A confirmation dialog is shown before signing out.
    expect(find.text('Log out'), findsOneWidget);
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(find.text('KAH KEN SHA NEY'), findsWidgets);
  });
}
