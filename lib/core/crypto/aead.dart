import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'secure_random.dart';
import 'vault_exceptions.dart';

/// AES-256-GCM with a 96-bit nonce and a 128-bit tag.
///
/// Wire format is `base64(nonce ‖ ciphertext ‖ tag)` with no header and no
/// additional authenticated data. Every sealed value in the app — the wrapped
/// data key and each credential field alike — uses exactly this shape.
const int nonceLength = 12;
const int macBits = 128;
const int keyLength = 32;

String seal(Uint8List key, List<int> plaintext) {
  final nonce = randomBytes(nonceLength);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), macBits, nonce, Uint8List(0)));
  final body = cipher.process(Uint8List.fromList(plaintext));
  return base64Encode(Uint8List.fromList(nonce + body));
}

Uint8List openSealed(Uint8List key, String sealed) {
  late final Uint8List combined;
  try {
    combined = base64Decode(sealed);
  } catch (_) {
    throw const VaultDecryptException('value is not valid base64');
  }
  if (combined.length <= nonceLength + (macBits ~/ 8)) {
    throw const VaultDecryptException('value is too short to be a sealed record');
  }

  final nonce = Uint8List.fromList(combined.sublist(0, nonceLength));
  final body = Uint8List.fromList(combined.sublist(nonceLength));

  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), macBits, nonce, Uint8List(0)));

  try {
    return cipher.process(body);
  } on InvalidCipherTextException {
    throw const VaultDecryptException('authentication tag mismatch');
  } catch (e) {
    throw VaultDecryptException('$e');
  }
}
