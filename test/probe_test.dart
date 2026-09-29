import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/main.dart';

/// Echo mock: initializeCore reports no apps; initializeApp echoes back the
/// requested options so the soft options check in MethodChannelFirebase passes.
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

void _setupMocks() {
  TestFirebaseCoreHostApi.setUp(_EchoCoreHostApi());
  // app check activate: success (reply <Object?>[null])
  final appCheckChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.firebase_app_check_platform_interface.FirebaseAppCheckHostApi.activate',
    // The App Check Pigeon codec only specializes ints (all Strings/nulls in
    // this message), so the standard codec is byte-compatible here.
    const StandardMessageCodec(),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(appCheckChannel, (message) async {
    return <Object?>[null];
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_setupMocks);

  testWidgets('probe landing timing', (WidgetTester tester) async {
    await tester.pumpWidget(const AmongApp());
    await tester.pump();
    var foundAt = -1;
    for (var i = 1; i <= 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Get Started').evaluate().isNotEmpty) {
        foundAt = i * 500;
        break;
      }
    }
    debugPrint('GetStarted appears at ~${foundAt}ms');
    debugPrint('ConnError=${find.text('Connection Error').evaluate().length} '
        'Title=${find.text('KAH KEN SHA NEY').evaluate().length} '
        'Footer=${find.textContaining('All rights reserved.').evaluate().length}');
    expect(foundAt, greaterThan(0));
    expect(find.textContaining('KAH KEN SHA NEY. All rights reserved.'), findsOneWidget);
  });
}

