class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.timedOut = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool timedOut;

  bool get isSuccess => exitCode == 0 && !timedOut;

  /// stdout when the command worked, stderr when it did not — what a caller
  /// almost always wants to show.
  String get output => isSuccess ? stdout : (stderr.isEmpty ? stdout : stderr);
}
