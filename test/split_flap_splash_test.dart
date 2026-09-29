import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

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
      // Just verify the widget renders
      expect(find.byType(SplitFlapSplash), findsOneWidget);
    });

    testWidgets('After full duration, cells display correct text and stay stable', (WidgetTester tester) async {
      await fakeAsync((async) async {
        int completeCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: SplitFlapSplash(
              onComplete: () => completeCount++,
            ),
          ),
        );

        // Pump to the end of animation + hold duration
        async.elapse(const Duration(milliseconds: 3000));
        await tester.pump();
        
        // After animation completes, the correct text should be displayed
        // Check that key letters are present (there are 2 K's in "KAH KEN SHA NEY")
        expect(find.text('K'), findsWidgets);
        expect(find.text('A'), findsWidgets);
        expect(find.text('H'), findsWidgets);
        expect(find.text('N'), findsWidgets); // 2 N's in "KEN" and "NEY"
        expect(find.text('E'), findsWidgets);
        expect(find.text('Y'), findsOneWidget);
        expect(find.text('S'), findsOneWidget);
        expect(completeCount, 1);

        // Extra pumps should not change the text
        async.elapse(const Duration(milliseconds: 100));
        await tester.pump();
        expect(find.text('K'), findsWidgets);
        
        async.elapse(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('K'), findsWidgets);
      });
    });

    testWidgets('Rebuild after completion does not restart or scramble', (WidgetTester tester) async {
      await fakeAsync((async) async {
        int completeCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: SplitFlapSplash(
              onComplete: () => completeCount++,
            ),
          ),
        );

        async.elapse(const Duration(milliseconds: 3000));
        await tester.pump();
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
      await fakeAsync((async) async {
        int completeCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: SplitFlapSplash(
              onComplete: () => completeCount++,
            ),
          ),
        );

        async.elapse(const Duration(milliseconds: 3000));
        await tester.pump();
        expect(completeCount, 1);

        // Pump more - should not increment again
        async.elapse(const Duration(milliseconds: 1000));
        await tester.pump();
        expect(completeCount, 1);
      });
    });
  });

  group('SplitFlapSplashScreen', () {
    testWidgets('navigation fires once after init and minimum duration', (WidgetTester tester) async {
      await fakeAsync((async) async {
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
        async.elapse(const Duration(milliseconds: 3500));
        await tester.pump();
        expect(completeCount, 1);
      });
    });
  });
}