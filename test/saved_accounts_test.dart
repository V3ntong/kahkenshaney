import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amongapp/models/saved_account.dart';
import 'package:amongapp/screens/auth/login.dart';
import 'package:amongapp/screens/dashboard.dart';
import 'package:amongapp/services/auth_service.dart';
import 'package:amongapp/services/saved_accounts_store.dart';
import 'package:amongapp/theme/app_theme.dart';

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  bool get isAuthenticated => false;

  @override
  bool get isAdminAuthenticated => false;

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
  Future<bool> refreshAdminStatus() async => false;
}

SavedAccount _account(String uid, String email, String name) => SavedAccount(
      uid: uid,
      email: email,
      displayName: name,
      photoUrl: null,
      lastLoginAt: DateTime(2026, 9, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedAccountsStore', () {
    test('saving an account after login persists it locally', () async {
      final store = SavedAccountsStore();
      await store.saveAccount(_account('u1', 'jane@example.com', 'Jane'));

      final accounts = await store.loadAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.first.uid, 'u1');
      expect(accounts.first.email, 'jane@example.com');
    });

    test('supports multiple saved accounts', () async {
      final store = SavedAccountsStore();
      await store.saveAccount(_account('u1', 'jane@example.com', 'Jane'));
      await store.saveAccount(_account('u2', 'bob@example.com', 'Bob'));
      await store.saveAccount(_account('u3', 'amy@example.com', 'Amy'));

      final accounts = await store.loadAccounts();
      expect(accounts, hasLength(3));
    });

    test('duplicate uid collapses into a single entry, most recent first',
        () async {
      final store = SavedAccountsStore();
      await store.saveAccount(_account('u1', 'old@example.com', 'Old'));
      await store.saveAccount(_account('u2', 'bob@example.com', 'Bob'));
      await store.saveAccount(_account('u1', 'jane@example.com', 'Jane'));

      final accounts = await store.loadAccounts();
      expect(accounts, hasLength(2));
      expect(accounts.first.uid, 'u1');
      expect(accounts.first.email, 'jane@example.com');
    });

    test('removing an account only clears the local reference', () async {
      final store = SavedAccountsStore();
      await store.saveAccount(_account('u1', 'jane@example.com', 'Jane'));
      await store.saveAccount(_account('u2', 'bob@example.com', 'Bob'));

      final remaining = await store.removeAccount('u1');
      expect(remaining, hasLength(1));
      expect(remaining.first.uid, 'u2');

      final reloaded = await store.loadAccounts();
      expect(reloaded, hasLength(1));
      expect(reloaded.first.uid, 'u2');
    });

    test('clearing app data wipes the list (empty prefs → no accounts)',
        () async {
      final store = SavedAccountsStore();
      await store.saveAccount(_account('u1', 'jane@example.com', 'Jane'));
      // Simulate app-data clear by resetting mock storage.
      SharedPreferences.setMockInitialValues({});

      final accounts = await store.loadAccounts();
      expect(accounts, isEmpty);
    });
  });

  group('Login screen account switcher', () {
    Future<void> pumpLogin(
      WidgetTester tester, {
      Map<String, Object> seed = const {},
    }) async {
      SharedPreferences.setMockInitialValues(seed);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LoginScreen(authService: _FakeAuthService()),
        ),
      );
      await tester.pumpAndSettle();
    }

    String seededAccountsJson() => jsonEncode([
          _account('u1', 'jane@example.com', 'Jane').toJson(),
          _account('u2', 'bob@example.com', 'Bob').toJson(),
        ]);

    testWidgets('shows saved accounts above the standard login form',
        (tester) async {
      await pumpLogin(
        tester,
        seed: {'saved_accounts_v1': seededAccountsJson()},
      );

      expect(find.text('Jane'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Create new account'), findsOneWidget);
      // The standard form remains below.
      expect(find.widgetWithText(TextField, 'Email Address'), findsOneWidget);
    });

    testWidgets('does NOT show the switcher when no accounts are saved',
        (tester) async {
      await pumpLogin(tester);

      expect(find.text('SAVED ACCOUNTS'), findsNothing);
      expect(find.widgetWithText(TextField, 'Email Address'), findsOneWidget);
    });

    testWidgets('tapping a saved account prefills email and never auto-logs-in',
        (tester) async {
      await pumpLogin(
        tester,
        seed: {'saved_accounts_v1': seededAccountsJson()},
      );

      await tester.tap(find.text('Jane'));
      await tester.pumpAndSettle();

      // Email prefilled, password re-entry required — no navigation happened.
      expect(find.text('jane@example.com'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      // No interstitial snackbar — user goes directly to password field.
      expect(
        find.textContaining('Enter your password to continue'),
        findsNothing,
      );
    });

    testWidgets('removing a saved account clears it from the switcher',
        (tester) async {
      await pumpLogin(
        tester,
        seed: {'saved_accounts_v1': seededAccountsJson()},
      );

      // Remove Jane via the tile's delete button (first tile).
      await tester.tap(find.byTooltip('Remove saved account').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove saved account?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Jane'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
    });
  });
}