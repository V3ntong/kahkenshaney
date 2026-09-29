import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/widgets/split_flap_splash.dart';

void main() {
  group('SplitFlapSplash', () {
    testWidgets('At t=0 the widget does not display the full correct text', (WidgetTester tester) async {
      int completeCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );

      // At frame 0, the text should be scrambled, not the final text
      final textFinder = find.text('KAH KEN SHA NEY');
      expect(textFinder, findsNothing);
    });

    testWidgets('After full duration, cells display correct text and stay stable', (WidgetTester tester) async {
      int completeCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );

      // Pump to the end of animation + hold duration
      await tester.pump(const Duration(milliseconds: 3000));
      
      // After animation completes, the correct text should be displayed
      expect(find.text('KAH KEN SHA NEY'), findsOneWidget);
      expect(completeCount, 1);

      // Extra pumps should not change the text
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('KAH KEN SHA NEY'), findsOneWidget);
      
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('KAH KEN SHA NEY'), findsOneWidget);
    });

    testWidgets('Rebuild after completion does not restart or scramble', (WidgetTester tester) async {
      int completeCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 3000));
      expect(completeCount, 1);

      // Force a rebuild by pumping with same widget
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('KAH KEN SHA NEY'), findsOneWidget);
      expect(completeCount, 1); // Should not have incremented again
    });

    testWidgets('disableAnimations skips animation and shows final text', (WidgetTester tester) async {
      int completeCount = 0;
      
      // Create a test widget that forces disableAnimations
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: SplitFlapSplash(
              onComplete: () => completeCount++,
            ),
          ),
        ),
      );

      // Should complete quickly without animation
      await tester.pump(const Duration(milliseconds: 1000));
      expect(completeCount, 1);
      expect(find.text('KAH KEN SHA NEY'), findsOneWidget);
    });

    testWidgets('navigation callback fires exactly once', (WidgetTester tester) async {
      int completeCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 3000));
      expect(completeCount, 1);

      // Pump more - should not increment again
      await tester.pump(const Duration(milliseconds: 1000));
      expect(completeCount, 1);
    });
  });

  group('SplitFlapSplashScreen', () {
    testWidgets('navigation fires once after init and minimum duration', (WidgetTester tester) async {
      int completeCount = 0;
      Future<void> initFuture() async {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplashScreen(
            initializationFuture: initFuture,
            onComplete: () => completeCount++,
          ),
        ),
      );

      // Should not complete immediately
      await tester.pump(const Duration(milliseconds: 500));
      expect(completeCount, 0);

      // After min duration + init, should complete
      await tester.pump(const Duration(milliseconds: 3500));
      expect(completeCount, 1);
    });
  });
}