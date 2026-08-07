import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/main.dart';
import 'package:amongapp/screens/auth/login.dart';
import 'package:amongapp/screens/auth/signup.dart';
import 'package:amongapp/widgets/app_button.dart';
import 'package:amongapp/widgets/otp_input.dart';
import 'package:amongapp/widgets/password_strength.dart';

void main() {
  testWidgets('Landing page renders hero, CTA and footer', (tester) async {
    await tester.pumpWidget(const AmongApp(firebaseReady: true));

    expect(find.text('KAH KEN SHA NEY'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.textContaining('KAH KEN SHA NEY. All rights reserved.'),
      findsOneWidget,
    );
  });

  testWidgets('Get Started navigates to the Login screen', (tester) async {
    await tester.pumpWidget(const AmongApp(firebaseReady: true));

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('Login rejects an invalid email format', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Email Address'),
      'not-an-email',
    );
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Register screen renders all required fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Create Account'), findsOneWidget);
  });

  testWidgets('Register shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    await tester.ensureVisible(
      find.widgetWithText(AppButton, 'Create Account'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required.'), findsOneWidget);
    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Please confirm your password.'), findsOneWidget);
  });

  testWidgets('Register rejects mismatched confirm password', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Full Name'),
      'Jane Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email Address'),
      'jane@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Abcdefg1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      'Different1',
    );

    await tester.ensureVisible(
      find.widgetWithText(AppButton, 'Create Account'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('OTP input completes once all six boxes are filled',
      (tester) async {
    String? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OtpInput(onCompleted: (code) => completed = code),
          ),
        ),
      ),
    );

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, 6);

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byType(TextField).at(i), '${i + 1}');
      await tester.pump();
    }

    expect(completed, '123456');
  });

  testWidgets('OTP input fits on narrow screens without overflowing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OtpInput(onCompleted: (_) {}),
          ),
        ),
      ),
    );

    final finder = find.byType(OtpInput);
    await tester.binding.setSurfaceSize(const Size(312, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();

    expect(finder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login renders unboxed layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);

    final loginY = tester.getTopLeft(find.widgetWithText(AppButton, 'Login')).dy;
    final passwordY = tester.getTopLeft(find.widgetWithText(TextField, 'Password')).dy;
    final forgotY = tester.getTopLeft(find.text('Forgot Password?')).dy;
    expect(passwordY, lessThan(loginY));
    expect(loginY, lessThan(forgotY));
  });

  testWidgets('Login uses clean generic hints', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('you@example.com'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('Register footer is anchored near the bottom and uses clean hints',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('you@example.com'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);

    final registerButtonY =
        tester.getTopLeft(find.widgetWithText(AppButton, 'Create Account')).dy;
    final footerY = tester.getTopLeft(find.text('Already have an account?')).dy;
    expect(footerY, greaterThan(registerButtonY));
  });

  testWidgets('Forgot Password opens its screen without exceptions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Password strength bar animates smoothly toward its target',
      (tester) async {
    var password = 'Abcdefg1!';
    void Function(VoidCallback)? update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PasswordStrengthBar(password: password);
            },
          ),
        ),
      ),
    );

    await tester.pump();
    final initial = tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .value!;

    await tester.pump(const Duration(milliseconds: 400));
    final settled = tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .value!;

    expect(initial, lessThan(0.1));
    expect(settled, closeTo(1.0, 0.05));

    update!(() => password = 'abc');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final midway = tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .value!;
    expect(midway, greaterThan(0.0));
    expect(midway, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 400));
    final shrunk = tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .value!;
    expect(shrunk, closeTo(0.0, 0.05));
  });

  testWidgets('Firebase error screen shows when firebaseReady is false',
      (tester) async {
    await tester.pumpWidget(const AmongApp(firebaseReady: false));

    expect(find.text('Connection Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Unable to connect'), findsOneWidget);
  });
}
