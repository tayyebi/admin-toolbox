import 'dart:convert';
import 'dart:typed_data';

/// Renders whatever dartssh2 hands the host key callback as a stable string.
///
/// The bytes are not one format across versions: dartssh2 2.13 and earlier
/// pass the raw 16-byte MD5 digest of the host key, 2.14 and later the UTF-8
/// bytes of an OpenSSH-style `SHA256:…` string. This project resolves to the
/// older form — every 2.x above 2.11 wants `meta ^1.16.0` or `pointycastle
/// ^4.0.0`, and neither is available here — but the resolution moves with the
/// Flutter SDK, so both forms are handled rather than assumed.
///
/// Decoding a raw digest as UTF-8 throws, and dartssh2 2.11 casts anything
/// thrown out of the callback to `SSHError` before reporting it. That cast
/// fails, the resulting TypeError is lost to the zone, and the handshake is
/// then never completed *or* failed — so the connection dies on the caller's
/// timeout with nothing pointing at the host key check.
abstract final class SshFingerprint {
  static String format(Uint8List bytes) {
    final formatted = _alreadyFormatted(bytes);
    if (formatted != null) return formatted;

    // A raw digest. SHA-256 is rendered the way OpenSSH and newer dartssh2 do,
    // base64 without padding; anything else as hex, how MD5 keys are read.
    if (bytes.length == 32) {
      return 'SHA256:${base64.encode(bytes).replaceAll('=', '')}';
    }
    return 'MD5:${_hex(bytes)}';
  }

  /// A digest that happens to decode as UTF-8 must not be mistaken for a
  /// fingerprint newer dartssh2 already formatted, so the algorithm prefix has
  /// to be there — that is what makes the two cases tellable apart.
  static String? _alreadyFormatted(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return null;
    }

    const prefixes = ['SHA256:', 'SHA1:', 'MD5:'];
    return prefixes.any(text.startsWith) ? text : null;
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(':');
}
