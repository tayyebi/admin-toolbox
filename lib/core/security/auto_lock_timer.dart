/// Tracks how long the app has been in the background.
class AutoLockTimer {
  DateTime? _since;

  void markBackgrounded() => _since = DateTime.now();

  void reset() => _since = null;

  /// True when the app stayed backgrounded at least [delay]. Consumes the
  /// mark either way, so a resume never re-triggers on a stale timestamp.
  bool expired(Duration delay) {
    final since = _since;
    _since = null;
    if (since == null) return false;
    return delay <= Duration.zero || DateTime.now().difference(since) >= delay;
  }
}
