/// A cancellation flag shared between an engine and the work it delegates.
///
/// Passed rather than read off the engine so the runners below stay
/// independent of it — and so cancelling one run cannot reach into another.
class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}
