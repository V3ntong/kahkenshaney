import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/utils/cooldown_timer.dart';

void main() {
  group('CooldownTimer', () {
    var now = DateTime(2026, 1, 1, 12, 0, 0);

    CooldownTimer buildTimer() => CooldownTimer(
          duration: const Duration(seconds: 60),
          now: () => now,
        );

    setUp(() => now = DateTime(2026, 1, 1, 12, 0, 0));

    test('is inactive before it starts', () {
      final timer = buildTimer();
      expect(timer.isActive, isFalse);
      expect(timer.remaining, Duration.zero);
    });

    test('becomes active after start', () {
      final timer = buildTimer();
      timer.start();
      expect(timer.isActive, isTrue);
      expect(timer.remainingSeconds, 60);
    });

    test('counts down with time', () {
      final timer = buildTimer();
      timer.start();
      now = now.add(const Duration(seconds: 20));
      expect(timer.remainingSeconds, 40);
    });

    test('expires after the duration', () {
      final timer = buildTimer();
      timer.start();
      now = now.add(const Duration(seconds: 61));
      expect(timer.isActive, isFalse);
      expect(timer.remaining, Duration.zero);
    });

    test('reset clears the cooldown', () {
      final timer = buildTimer();
      timer.start();
      timer.reset();
      expect(timer.isActive, isFalse);
    });

    test('restarting after expiry begins a fresh window', () {
      final timer = buildTimer();
      timer.start();
      now = now.add(const Duration(seconds: 61));
      expect(timer.isActive, isFalse);
      timer.start();
      expect(timer.isActive, isTrue);
      expect(timer.remainingSeconds, 60);
    });
  });
}
