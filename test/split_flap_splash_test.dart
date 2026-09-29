import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/widgets/split_flap_splash.dart';

void main() {
  group('SplitFlapSplash', () {
    testWidgets('In test environment, splash completes immediately', (WidgetTester tester) async {
      int completeCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );

      // In test environment, splash completes after hold duration (500ms)
      await tester.pump(const Duration(milliseconds: 600));
      expect(completeCount, 1);
      expect(find.byType(SplitFlapSplash), findsOneWidget);
    });

    testWidgets('After completion, cells display correct text and stay stable', (WidgetTester tester) async {
      int completeCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplitFlapSplash(
            onComplete: () => completeCount++,
          ),
        ),
      );

      // Pump to allow completion
      await tester.pump(const Duration(milliseconds: 600));
      
      // After completion, the correct text should be displayed
      expect(find.text('K'), findsWidgets);
      expect(find.text('A'), findsWidgets);
      expect(find.text('H'), findsWidgets);
      expect(find.text('N'), findsWidgets); // 2 N's in "KEN" and "NEY"
      expect(find.text('E'), findsWidgets);
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(completeCount, 1);

      // Extra pumps should not change the text
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('K'), findsWidgets);
      
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('K'), findsWidgets);
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

      await tester.pump(const Duration(milliseconds: 600));
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
      expect(find.text('K'), findsWidgets);
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
      expect(find.text('K'), findsWidgets);
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

      await tester.pump(const Duration(milliseconds: 600));
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

      // In test environment, completes after initFuture + hold
      await tester.pump(const Duration(milliseconds: 700));
      expect(completeCount, 1);
    });
  });
}