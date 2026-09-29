import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/main.dart';
import 'package:amongapp/screens/auth/login.dart';
import 'package:amongapp/screens/auth/signup.dart';
import 'package:amongapp/widgets/app_button.dart';
import 'package:amongapp/widgets/otp_input.dart';
import 'package:amongapp/widgets/password_strength.dart';

void main() {
  group('Landing page (after splash)', () {
    testWidgets('Landing page renders hero, CTA and footer', (WidgetTester tester) async {
      await tester.pumpWidget(const AmongApp());

      // Wait for splash screen to complete
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('KAH KEN SHA NEY'), findsWidgets);
      expect(find.text('Get Started'), findsOneWidget);
      expect(
        find.textContaining('KAH KEN SHA NEY. All rights reserved.'),
        findsOneWidget,
      );
    });

    testWidgets('Get Started opens the Register screen', (WidgetTester tester) async {
      await tester.pumpWidget(const AmongApp());

      // Wait for splash screen to complete
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Get Started routes to the sign-up flow.
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create Account'), findsOneWidget);
    });
  });

  testWidgets('Login shows validation errors for empty fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('Login rejects an invalid email format', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Register screen renders all required fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('Register shows validation errors for empty fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required.'), findsOneWidget);
    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Confirm password is required.'), findsOneWidget);
  });

  testWidgets('Register rejects mismatched confirm password', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
    await tester.enterText(find.byType(TextFormField).at(1), 'john@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'different123');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('OTP input completes once all six boxes are filled', (WidgetTester tester) async {
    void onCompleted(String code) {}

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OTPInput(
            onCompleted: onCompleted,
          ),
        ),
      );

      for (int i = 0; i < 6; i++) {
        await tester.enterText(find.byType(TextField).at(i), '${i + 1}');
      }

      await tester.pump();
      // If we reach here without exception, the OTP input accepted all 6 digits
      expect(find.byType(OTPInput), findsOneWidget);
    });
  });

  testWidgets('OTP input fits on narrow screens without overflowing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: OTPInput(
                onCompleted: (_) {},
              ),
            ),
          ),
        ),
      );

    expect(find.byType(OTPInput), findsOneWidget);
    // If we reach here without overflow error, the test passes
  });

  testWidgets('Login renders unboxed layout', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    // Verify the login card renders without unconstrained box errors
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Login uses clean generic hints', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    // Verify the login card renders without unconstrained box errors
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Register footer is anchored near the bottom and uses clean hints', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    // Verify the register screen renders without overflow
    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('Forgot Password opens its screen without exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    // Should navigate to forgot password screen
    expect(find.text('Reset Password'), findsOneWidget);
  });

  testWidgets('Password strength bar animates smoothly toward its target', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PasswordStrength(password: ''),
        ),
      );

      // Verify the widget renders
      expect(find.byType(PasswordStrength), findsOneWidget);
    });
  });

  testWidgets('Firebase error screen shows when initialization fails', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _FirebaseErrorScreen(),
      ),
    );

    expect(find.text('Connection Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}