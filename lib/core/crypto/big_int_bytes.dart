import 'dart:typed_data';

/// Big-endian, minimal-length magnitude bytes of a [BigInt].
///
/// Shared because both the SSH `mpint` and the DER `INTEGER` encodings build on
/// it, and both then prepend a zero byte when the high bit is set.
Uint8List bigIntToBytes(BigInt value) {
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
