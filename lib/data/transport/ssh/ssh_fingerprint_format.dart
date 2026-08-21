import 'dart:typed_data';

/// One dialect of the fingerprint argument dartssh2 passes `onVerifyHostKey`.
///
/// dartssh2 has changed what those bytes are, and the resolved version is not
/// this project's decision alone — the Flutter SDK's pinned `meta` and this
/// app's `pointycastle` both steer it. So the dialect is recognised from the
/// bytes rather than assumed from a version number, and supporting a new one
/// means adding a subclass, not another branch inside a decoder.
///
/// Every implementation must be total: [render] may not throw for bytes its
/// own [matches] accepted. This layer is a guard, and a throw here is what
/// hung the handshake in the first place.
abstract class SshFingerprintFormat {
  const SshFingerprintFormat();

  /// How this dialect is named in the connection log, so the next person to
  /// read a failing handshake can see which one was applied.
  String get name;

  /// Whether these bytes are what this dialect produces.
  bool matches(Uint8List bytes);

  /// The fingerprint as the user is shown it and as it is pinned.
  String render(Uint8List bytes);
}

/// Lowercase hex pairs, colon separated — how OpenSSH prints a raw digest.
String hexDigest(Uint8List bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(':');
