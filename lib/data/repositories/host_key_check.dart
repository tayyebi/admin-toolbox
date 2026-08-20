import 'known_host.dart';

enum HostKeyVerdict {
  /// Never seen — the user must decide whether to trust it.
  unknown,

  /// Matches the pinned key.
  trusted,

  /// A *different* key than the one pinned. Either the server was rebuilt, or
  /// something is intercepting the connection. Connections are refused.
  mismatch,
}

class HostKeyCheck {
  const HostKeyCheck(this.verdict, {this.pinned});
  final HostKeyVerdict verdict;
  final KnownHost? pinned;
}
