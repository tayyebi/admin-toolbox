import 'dart:convert';
import 'dart:typed_data';

import 'ssh_fingerprint_format.dart';

/// **dartssh2 >= 2.18.0**, 3.x included. `_hostkeyFingerprint` hashes the host
/// key with SHA-256 and hands over the UTF-8 bytes of
/// `SHA256:<base64, padding stripped>` — already what `ssh-keygen -lf` prints.
class PreformattedFingerprint extends SshFingerprintFormat {
  const PreformattedFingerprint();

  static const _prefixes = ['SHA256:', 'SHA1:', 'MD5:'];

  @override
  String get name => 'a pre-formatted fingerprint (dartssh2 >= 2.18)';

  @override
  bool matches(Uint8List bytes) => _decode(bytes) != null;

  @override
  String render(Uint8List bytes) => _decode(bytes)!;

  /// A digest that happens to be valid UTF-8 must not pass for a formatted
  /// string, so the algorithm prefix has to be present. That prefix is the
  /// only thing that reliably separates this dialect from a raw digest.
  static String? _decode(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return null;
    }
    return _prefixes.any(text.startsWith) ? text : null;
  }
}

/// **dartssh2 <= 2.17.0**, which is what this project resolves to: the raw
/// 16-byte MD5 digest of the host key, no prefix and no encoding. Rendered the
/// way `ssh-keygen -E md5 -lf` prints it, so it can be compared by hand.
class Md5DigestFingerprint extends SshFingerprintFormat {
  const Md5DigestFingerprint();

  @override
  String get name => 'a raw MD5 digest (dartssh2 <= 2.17)';

  @override
  bool matches(Uint8List bytes) => bytes.length == 16;

  @override
  String render(Uint8List bytes) => 'MD5:${hexDigest(bytes)}';
}

/// No released dartssh2 hands over a bare SHA-256 digest. This is here so a
/// future one that drops the `SHA256:` prefix is rendered as OpenSSH would
/// rather than being mistaken for something else.
class Sha256DigestFingerprint extends SshFingerprintFormat {
  const Sha256DigestFingerprint();

  @override
  String get name => 'a raw SHA-256 digest';

  @override
  bool matches(Uint8List bytes) => bytes.length == 32;

  @override
  String render(Uint8List bytes) =>
      'SHA256:${base64.encode(bytes).replaceAll('=', '')}';
}

/// Terminal fallback: bytes no known dialect claims. Renders them as hex so an
/// unrecognised dartssh2 still produces a stable, comparable string. The point
/// of this layer is that an unknown library version cannot hang a handshake;
/// the user is left with a decision to make, not a connection that never ends.
class OpaqueDigestFingerprint extends SshFingerprintFormat {
  const OpaqueDigestFingerprint();

  @override
  String get name => 'an unrecognised fingerprint format';

  @override
  bool matches(Uint8List bytes) => true;

  @override
  String render(Uint8List bytes) => 'UNKNOWN:${hexDigest(bytes)}';
}
