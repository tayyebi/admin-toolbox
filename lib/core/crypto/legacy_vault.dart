import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'digest.dart';
import 'vault_keys.dart';
import 'vault_storage.dart';

/// Reads the v1 AES-CBC scheme, used only while migrating a vault forward.
///
/// v1 kept the derived key itself in secure storage and used unauthenticated
/// CBC, so a wrong key yields plausible garbage rather than an error. Callers
/// must sanity-check whatever comes back.
class LegacyVault {
  const LegacyVault(this._storage);

  final VaultStorage _storage;

  Future<bool> exists() async {
    final legacy = await _storage.read(VaultKeys.legacyKey);
    return legacy != null && legacy.isNotEmpty;
  }

  /// Verifies [password] by reproducing the v1 derivation exactly.
  Future<bool> verifyPassword(String password) async {
    final storedKey = await _storage.read(VaultKeys.legacyKey);
    final storedSalt = await _storage.read(VaultKeys.legacySalt);
    if (storedKey == null || storedSalt == null) return false;

    final digest = sha256OfBytes(
      Uint8List.fromList(utf8.encode(password) + base64Decode(storedSalt)),
    );
    return base64Encode(utf8.encode(hexEncode(digest).substring(0, 32))) == storedKey;
  }

  Future<String?> decryptValue(String ciphertext) async {
    final legacyKeyRaw = await _storage.read(VaultKeys.legacyKey);
    if (legacyKeyRaw == null) return null;

    try {
      final key = base64Decode(legacyKeyRaw);
      final combined = base64Decode(ciphertext);
      if (combined.length <= 16) return null;

      final iv = Uint8List.fromList(combined.sublist(0, 16));
      final body = Uint8List.fromList(combined.sublist(16));

      final cipher = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV(KeyParameter(key), iv));

      final out = Uint8List(body.length);
      for (var offset = 0; offset < body.length;) {
        offset += cipher.processBlock(body, offset, out, offset);
      }

      return _stripPadding(out);
    } catch (_) {
      return null;
    }
  }

  /// Discards v1 material once every record has been re-encrypted.
  Future<void> clear() async {
    await _storage.delete(VaultKeys.legacySalt);
    await _storage.delete(VaultKeys.legacyKey);
  }

  static String? _stripPadding(Uint8List out) {
    final padLength = out.isEmpty ? 0 : out.last;
    if (padLength <= 0 || padLength > 16 || padLength > out.length) return null;
    return utf8.decode(out.sublist(0, out.length - padLength));
  }
}
