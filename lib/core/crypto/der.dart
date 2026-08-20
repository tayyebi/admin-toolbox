import 'dart:convert';
import 'dart:typed_data';

import 'big_int_bytes.dart';

/// Just enough DER to write a PKCS#1 `RSAPrivateKey`.
///
/// Written by hand rather than pulled from a library: it is small, fully
/// specified, and doing it here means the key format does not depend on
/// internals of a package that may change shape between releases.
class Der {
  Der._();

  static Uint8List integer(BigInt value) {
    var bytes = bigIntToBytes(value);
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
