import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'big_int_bytes.dart';

export 'der.dart'; // Used to live here; re-exported so importers see one surface.

/// SSH wire format (RFC 4251 §5).
///
/// Hand-written rather than taken from a library: it is small, fully specified,
/// and the key format then cannot shift under us when a package changes shape.
class SshWire {
  SshWire._();

  /// `string`: a uint32 big-endian length followed by that many bytes.
  static Uint8List string(List<int> bytes) {
    final out = BytesBuilder();
    out.add(_uint32(bytes.length));
    out.add(bytes);
    return out.toBytes();
  }

  static Uint8List utf8String(String value) => string(utf8.encode(value));

  /// `mpint`: a signed big-endian integer. A leading zero byte is required
  /// when the high bit is set, otherwise the value reads as negative.
  static Uint8List mpint(BigInt value) {
    if (value == BigInt.zero) return _uint32(0);

    var bytes = bigIntToBytes(value);
    if (bytes.first & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    return string(bytes);
  }

  static Uint8List _uint32(int value) {
    final out = Uint8List(4);
    ByteData.view(out.buffer).setUint32(0, value, Endian.big);
    return out;
  }

  /// The `ssh-rsa` public key blob: the algorithm name, then e, then n.
  static Uint8List rsaPublicBlob(BigInt exponent, BigInt modulus) {
    final out = BytesBuilder();
    out.add(utf8String('ssh-rsa'));
    out.add(mpint(exponent));
    out.add(mpint(modulus));
    return out.toBytes();
  }

  /// The single-line form written to `authorized_keys`.
  static String authorizedKeyLine(String algorithm, Uint8List blob, String? comment) {
    final encoded = base64Encode(blob);
    final trailer = (comment == null || comment.isEmpty) ? '' : ' $comment';
    return '$algorithm $encoded$trailer';
  }

  /// `SHA256:…`, matching `ssh-keygen -lf`. OpenSSH prints it unpadded.
  static String fingerprintOf(Uint8List publicKeyBlob) {
    final digest = sha256.convert(publicKeyBlob).bytes;
    return 'SHA256:${base64Encode(digest).replaceAll('=', '')}';
  }

  /// Recovers the fingerprint from a pasted `ssh-…` public key line.
  /// Returns null when the line is not a well-formed public key.
  static String? fingerprintOfPublicKeyLine(String line) {
    final blob = publicKeyBlobFromLine(line);
    return blob == null ? null : fingerprintOf(blob);
  }

  static Uint8List? publicKeyBlobFromLine(String line) {
    final parts = _split(line);
    if (parts.length < 2 || !_isAlgorithm(parts[0])) return null;
    try {
      return base64Decode(parts[1]);
    } catch (_) {
      return null;
    }
  }

  /// The algorithm name from a public key line, e.g. `ssh-ed25519`.
  static String? algorithmOfPublicKeyLine(String line) {
    final parts = _split(line);
    if (parts.isEmpty) return null;
    return _isAlgorithm(parts.first) ? parts.first : null;
  }

  static String? commentOfPublicKeyLine(String line) {
    final parts = _split(line);
    return parts.length >= 3 ? parts.sublist(2).join(' ') : null;
  }

  static List<String> _split(String line) => line.trim().split(RegExp(r'\s+'));

  static bool _isAlgorithm(String value) =>
      value.startsWith('ssh-') || value.startsWith('ecdsa-');
}
