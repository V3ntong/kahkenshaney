import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/main.dart';
import 'package:amongapp/screens/auth/login.dart';
import 'package:amongapp/screens/auth/signup.dart';
import 'package:amongapp/widgets/app_button.dart';
import 'package:amongapp/widgets/otp_input.dart';
import 'package:amongapp/widgets/password_strength.dart';

/// Test double for Firebase core's Pigeon host API.
///
/// [initializeCore] reports no pre-existing apps and [initializeApp] echoes
/// back the requested options, so `MethodChannelFirebase`'s soft options
/// check passes and [AmongApp] completes its Firebase initialization under
/// `flutter test`, where the real platform channels never respond.
class _EchoCoreHostApi implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: initializeAppRequest,
      pluginConstants: <String?, Object?>{},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async =>
      <CoreInitializeResponse>[];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async =>
      CoreFirebaseOptions(
        apiKey: 'test-key',
        appId: 'test-app',
        messagingSenderId: 'test-sender',
        projectId: 'test-project',
      );
}

const String _appCheckActivateChannelName =
    'dev.flutter.pigeon.'
    'firebase_app_check_platform_interface.'
    'FirebaseAppCheckHostApi.activate';

/// Registers (or, when [handler] is null, removes) the mock for the Firebase
/// App Check `activate` Pigeon channel.
void _registerAppCheckActivateHandler(
  Future<Object?> Function(Object? message)? handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(
        const BasicMessageChannel<Object?>(
          _appCheckActivateChannelName,
          // The App Check Pigeon codec only specializes ints (all Strings/nulls
          // travel on this channel), so the standard codec is byte-compatible.
          StandardMessageCodec(),
        ),
        handler,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Landing page (after splash)', () {
    // Drive the real entry widget end to end: Firebase initialization is
    // mocked so AmongApp can progress past its native placeholder, through
    // the split-flap splash, to the landing page — as it does on a device.
    setUp(() {
      TestFirebaseCoreHostApi.setUp(_EchoCoreHostApi());
      _registerAppCheckActivateHandler((message) async => <Object?>[null]);
    });

    tearDown(() {
      TestFirebaseCoreHostApi.setUp(null);
      _registerAppCheckActivateHandler(null);
    });

    testWidgets('Landing page renders hero, CTA and footer', (tester) async {
      await tester.pumpWidget(const AmongApp());

      // Flush the (mocked) Firebase initialization so the splash mounts.
      await tester.pump();

      // Wait for splash screen to complete
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('KAH KEN SHA NEY'), findsWidgets);
      expect(find.text('Get Started'), findsOneWidget);
      expect(
        find.textContaining('KAH KEN SHA NEY. All rights reserved.'),
        findsOneWidget,
      );
    });

    testWidgets('Get Started opens the Register screen', (tester) async {
      await tester.pumpWidget(const AmongApp());

      // Flush the (mocked) Firebase initialization so the splash mounts.
      await tester.pump();

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

  testWidgets('Login shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('Login rejects an invalid email format', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email Address'),
      'not-an-email',
    );
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Register screen renders all required fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Create Account'), findsOneWidget);
  });

  testWidgets('Register shows validation errors for empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

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
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

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

  testWidgets('OTP input completes once all six boxes are filled', (
    tester,
  ) async {
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

  testWidgets('OTP input fits on narrow screens without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: OtpInput(onCompleted: (_) {})),
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
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // The animated auth header renders the title uppercased.
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);

    final loginY = tester
        .getTopLeft(find.widgetWithText(AppButton, 'Login'))
        .dy;
    final passwordY = tester
        .getTopLeft(find.widgetWithText(TextField, 'Password'))
        .dy;
    final forgotY = tester.getTopLeft(find.text('Forgot Password?')).dy;
    expect(passwordY, lessThan(loginY));
    expect(loginY, lessThan(forgotY));
  });

  testWidgets('Login uses clean generic hints', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('you@example.com'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets(
    'Register footer is anchored near the bottom and uses clean hints',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('surname.name@smctagum.edu.ph'), findsOneWidget);
      expect(find.text('you@example.com'), findsNothing);
      expect(find.text('Jane Doe'), findsNothing);

      final registerButtonY = tester
          .getTopLeft(find.widgetWithText(AppButton, 'Create Account'))
          .dy;
      final footerY = tester
          .getTopLeft(find.text('Already have an account?'))
          .dy;
      expect(footerY, greaterThan(registerButtonY));
    },
  );

  testWidgets('Forgot Password opens its screen without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    // The animated auth header renders the title uppercased.
    expect(find.text('FORGOT PASSWORD'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Password strength bar animates smoothly toward its target', (
    tester,
  ) async {
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
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    await tester.pump(const Duration(milliseconds: 400));
    final settled = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    expect(initial, lessThan(0.1));
    expect(settled, closeTo(1.0, 0.05));

    update!(() => password = 'abc');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final midway = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(midway, greaterThan(0.0));
    expect(midway, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 400));
    final shrunk = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(shrunk, closeTo(0.0, 0.05));
  });

  testWidgets('Firebase error screen shows when initialization fails', (
    tester,
  ) async {
    // Firebase core succeeds but App Check activation fails with a channel
    // error, so AmongApp's FutureBuilder lands in its error state.
    TestFirebaseCoreHostApi.setUp(_EchoCoreHostApi());
    _registerAppCheckActivateHandler((message) async => null);
    addTearDown(() {
      TestFirebaseCoreHostApi.setUp(null);
      _registerAppCheckActivateHandler(null);
    });

    await tester.pumpWidget(const AmongApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Connection Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('App shows initialization placeholder while Firebase starts', (
    tester,
  ) async {
    await tester.pumpWidget(const AmongApp());
    await tester.pump(const Duration(seconds: 1));

    // Firebase is unavailable in the test environment, so the app must stay
    // on the initialization placeholder instead of crashing or navigating.
    expect(find.text('KAH KEN SHA NEY'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
