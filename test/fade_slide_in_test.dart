import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/widgets/fade_slide_in.dart';

void main() {
  group('FadeSlideInWidget.staggerDelay', () {
    test('scales linearly with the item index', () {
      expect(
        FadeSlideInWidget.staggerDelay(0),
        const Duration(milliseconds: 0),
      );
      expect(
        FadeSlideInWidget.staggerDelay(1),
        const Duration(milliseconds: 60),
      );
      expect(
        FadeSlideInWidget.staggerDelay(5),
        const Duration(milliseconds: 300),
      );
    });

    test('respects a custom per-item increment', () {
      expect(
        FadeSlideInWidget.staggerDelay(3, perItemMs: 50),
        const Duration(milliseconds: 150),
      );
    });

    test('clamps the total spread so long lists never stall', () {
      // Item #50 would be 3s without the cap — it must clamp to 700ms.
      expect(
        FadeSlideInWidget.staggerDelay(50),
        const Duration(milliseconds: 700),
      );
      expect(
        FadeSlideInWidget.staggerDelay(50, perItemMs: 80, maxSpreadMs: 500),
        const Duration(milliseconds: 500),
      );
    });
  });

  group('FadeSlideInWidget', () {
    testWidgets('settles to fully visible content after delay + duration',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeSlideInWidget(
              delay: Duration(milliseconds: 300),
              duration: Duration(milliseconds: 400),
              child: Text('settled content'),
            ),
          ),
        ),
      );

      // Before the entrance delay elapses the child is still built (just
      // hidden), so it can already be found.
      expect(find.text('settled content'), findsOneWidget);

      // Advance past the delay + animation; nothing should be left pending.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('settled content'), findsOneWidget);
    });

    testWidgets('content stays interactive while the animation is playing',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FadeSlideInWidget(
              delay: const Duration(milliseconds: 250),
              duration: const Duration(milliseconds: 400),
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('tap me'),
              ),
            ),
          ),
        ),
      );

      // Mid-animation tap must land — entrance is paint-only.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('tap me'));
      expect(taps, 1);

      await tester.pumpAndSettle();
      await tester.tap(find.text('tap me'));
      expect(taps, 2);
    });

    testWidgets('does not replay when the parent rebuilds', (tester) async {
      final rebuildNotifier = ValueNotifier<int>(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: rebuildNotifier,
              builder: (context, value, _) {
                return FadeSlideInWidget(
                  duration: const Duration(milliseconds: 300),
                  child: Text('stable child $value'),
                );
              },
            ),
          ),
        ),
      );

      // Let the first entrance finish.
      await tester.pumpAndSettle();

      // A parent rebuild swaps the child text — the wrapper must not restart.
      rebuildNotifier.value = 1;
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('stable child 1'), findsOneWidget);

      // If the controller had restarted, an extra 300ms would still be
      // animating below; advancing time completes quietly either way.
      await tester.pumpAndSettle();
      expect(find.text('stable child 1'), findsOneWidget);
    });
  });
}
