import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// OWASP's 2023 floor for PBKDF2-HMAC-SHA256. Persisted per vault so the
/// figure can be raised later without locking out existing users.
const int defaultIterations = 210000;

const int saltLength = 16;

/// Derives a 32-byte key off the UI isolate.
///
/// At 210k iterations this blocks for around a second on mid-range hardware,
/// which would drop frames on the lock screen.
Future<Uint8List> deriveKey(String password, Uint8List salt, int iterations) {
  return compute(
    pbkdf2,
    Pbkdf2Request(password: password, salt: salt, iterations: iterations),
  );
}

@immutable
class Pbkdf2Request {
  const Pbkdf2Request({
    required this.password,
    required this.salt,
    required this.iterations,
  });

  final String password;
  final Uint8List salt;
  final int iterations;
}

/// Top-level so it can run in a background isolate via [compute].
Uint8List pbkdf2(Pbkdf2Request request) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(request.salt, request.iterations, 32));
  return derivator.process(Uint8List.fromList(utf8.encode(request.password)));
}
