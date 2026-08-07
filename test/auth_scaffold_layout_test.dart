import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/screens/auth/otp_screen.dart';
import 'package:amongapp/services/auth_service.dart';

class _FakeAuth extends AuthService {
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
  Future<void> signOut() async {}

  @override
  User? get currentUser => null;
}

void main() {
  Future<void> pumpOtpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OtpScreen(
          email: 'jane@example.com',
          purpose: OtpPurpose.verifyEmail,
          authService: _FakeAuth(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('OTP screen renders all controls at small phone size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpOtpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(tester.widgetList<TextField>(find.byType(TextField)).length, 6);
    expect(find.text('Verify Code'), findsOneWidget);
    expect(find.text('Resend in 0:59'), findsOneWidget);
  });

  testWidgets('OTP screen renders all controls at default test size',
      (tester) async {
    await pumpOtpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(tester.widgetList<TextField>(find.byType(TextField)).length, 6);
    expect(find.text('Verify Code'), findsOneWidget);
  });

  testWidgets('OTP screen renders all controls at large tablet size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1366));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpOtpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(tester.widgetList<TextField>(find.byType(TextField)).length, 6);
    expect(find.text('Verify Code'), findsOneWidget);
  });
}
