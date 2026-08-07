/// Countdown used for resend cooldowns (verification email / OTP resend).
///
/// Uses an injectable clock so it can be tested deterministically.
class CooldownTimer {
  CooldownTimer({
    required this.duration,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration duration;
  final DateTime Function() _now;

  DateTime? _lastStart;

  bool get isActive {
    final last = _lastStart;
    if (last == null) return false;
    return _now().difference(last) < duration;
  }

  Duration get remaining {
    final last = _lastStart;
    if (last == null) return Duration.zero;
    final diff = duration - _now().difference(last);
    return diff.isNegative ? Duration.zero : diff;
  }

  int get remainingSeconds => remaining.inSeconds.clamp(0, 1 << 31);

  void start() => _lastStart = _now();

  void reset() => _lastStart = null;
}
