import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Minimal encoders for the two binary formats SSH keys live in.
///
/// Both are written by hand rather than pulled from a library: they are small,
/// fully specified, and doing it here means the key format does not depend on
/// internals of a package that may change shape between releases.

/// SSH wire format (RFC 4251 §5).
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

    var bytes = _bigIntToBytes(value);
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

  static Uint8List _bigIntToBytes(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
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
    final encoded = base64Encode(digest).replaceAll('=', '');
    return 'SHA256:$encoded';
  }

  /// Recovers the fingerprint from a pasted `ssh-…` public key line.
  /// Returns null when the line is not a well-formed public key.
  static String? fingerprintOfPublicKeyLine(String line) {
    final blob = publicKeyBlobFromLine(line);
    return blob == null ? null : fingerprintOf(blob);
  }

  static Uint8List? publicKeyBlobFromLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || !parts[0].startsWith('ssh-') && !parts[0].startsWith('ecdsa-')) {
      return null;
    }
    try {
      return base64Decode(parts[1]);
    } catch (_) {
      return null;
    }
  }

  /// The algorithm name from a public key line, e.g. `ssh-ed25519`.
  static String? algorithmOfPublicKeyLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    final algorithm = parts.first;
    return algorithm.startsWith('ssh-') || algorithm.startsWith('ecdsa-') ? algorithm : null;
  }

  static String? commentOfPublicKeyLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    return parts.length >= 3 ? parts.sublist(2).join(' ') : null;
  }
}

/// Just enough DER to write a PKCS#1 `RSAPrivateKey`.
class Der {
  Der._();

  static Uint8List integer(BigInt value) {
    var bytes = SshWire._bigIntToBytes(value);
    if (bytes.isEmpty) bytes = Uint8List.fromList([0]);
    // DER integers are signed; a leading zero keeps positives positive.
    if (bytes.first & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    return _tagged(0x02, bytes);
  }

  static Uint8List sequence(List<Uint8List> elements) {
    final body = BytesBuilder();
    for (final element in elements) {
      body.add(element);
    }
    return _tagged(0x30, body.toBytes());
  }

  static Uint8List _tagged(int tag, List<int> body) {
    final out = BytesBuilder();
    out.addByte(tag);
    out.add(_length(body.length));
    out.add(body);
    return out.toBytes();
  }

  static Uint8List _length(int length) {
    if (length < 0x80) return Uint8List.fromList([length]);

    final bytes = <int>[];
    var remaining = length;
    while (remaining > 0) {
      bytes.insert(0, remaining & 0xFF);
      remaining >>= 8;
    }
    return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
  }

  /// Wraps DER bytes in a PEM armour block with 64-character lines.
  static String toPem(Uint8List der, String label) {
    final body = base64Encode(der);
    final buffer = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < body.length; i += 64) {
      buffer.writeln(body.substring(i, i + 64 > body.length ? body.length : i + 64));
    }
    buffer.write('-----END $label-----\n');
    return buffer.toString();
  }
}
