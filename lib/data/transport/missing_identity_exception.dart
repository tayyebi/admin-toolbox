import '../models/host.dart';

/// Thrown when a host has no usable credential attached.
///
/// This was the app's most consequential silent failure: the session lookup
/// returned null and every host simply showed as offline, with nothing
/// pointing at the actual cause.
class MissingIdentityException implements Exception {
  const MissingIdentityException(this.host);

  final Host host;

  @override
  String toString() =>
      'No credential is attached to ${host.name}. Open the host and choose an '
      'identity from the vault.';
}
