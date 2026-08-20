import 'dart:math' as math;

/// Back-off applied after repeated wrong passwords.
///
/// Note what this does *not* survive: the counter lives in memory, so force
/// quitting the app resets it. That is tolerable against a long master
/// password and would not be against a short PIN.
abstract final class LockAttemptPolicy {
  /// Attempts allowed before back-off starts.
  static const int freeAttempts = 3;

  /// 5s, 10s, 20s, 40s … capped at five minutes.
  static Duration? lockoutAfter(int attempts) {
    if (attempts <= freeAttempts) return null;
    return Duration(seconds: math.min(5 * (1 << (attempts - freeAttempts - 1)), 300));
  }
}
