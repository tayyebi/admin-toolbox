import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Cryptographically secure random bytes.
Uint8List randomBytes(int length) {
  final random = math.Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
}

/// Overwrites key material in place.
///
/// Dart gives no guarantee the buffer is not copied by the GC first, so this
/// shortens the window rather than closing it. It is still worth doing: a heap
/// dump taken after lock should not contain the key.
void wipeBytes(Uint8List bytes) {
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = 0;
  }
}

const _passwordAlphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?';

String generatePassword({int length = 24}) {
  final bytes = randomBytes(length);
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_passwordAlphabet[bytes[i] % _passwordAlphabet.length]);
  }
  return buffer.toString();
}
