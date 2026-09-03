import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/screens/admin_dashboard.dart';
import 'package:amongapp/screens/auth/login.dart';
import 'package:amongapp/screens/dashboard.dart';
import 'package:amongapp/services/auth_service.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.isAdmin = false, this.isAuthed = false});

  final bool isAdmin;
  final bool isAuthed;

  @override
  User? get currentUser => null;

  @override
  bool get isAuthenticated => isAuthed;

  @override
  bool get isAdminAuthenticated => isAdmin;

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
  Future<bool> refreshAdminStatus() async => isAdmin;
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Email Address'),
    'admin@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Password'),
    'Abcdefg1',
  );
  await tester.tap(find.text('Login'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('isAdminEmail', () {
    test('matches the admin email case-insensitively', () {
      expect(isAdminEmail(kAdminEmail), isTrue);
      expect(isAdminEmail(kAdminEmail.toUpperCase()), isTrue);
    });

    test('ignores surrounding whitespace', () {
      expect(isAdminEmail('  $kAdminEmail  '), isTrue);
    });

    test('rejects non-admin emails, null and empty', () {
      expect(isAdminEmail('user@example.com'), isFalse);
      expect(isAdminEmail('admin@other.com'), isFalse);
      expect(isAdminEmail(null), isFalse);
      expect(isAdminEmail(''), isFalse);
    });
  });

  group('Login redirects', () {
    testWidgets('admin login opens the Admin Dashboard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: _FakeAuthService(isAdmin: true)),
        ),
      );

      await _submitLogin(tester);

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    });

    testWidgets('normal user login opens the User Dashboard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: _FakeAuthService()),
        ),
      );

      await _submitLogin(tester);

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
    });
  });

  group('Admin Dashboard access guard', () {
    testWidgets('signed-out users are sent to the Login screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authService: _FakeAuthService(isAuthed: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('non-admin users are redirected away from the Admin Dashboard',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authService: _FakeAuthService(isAuthed: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
