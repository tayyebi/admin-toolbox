import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'aead.dart';
import 'kdf.dart';
import 'secure_random.dart';
import 'vault_exceptions.dart';
import 'vault_keys.dart';
import 'vault_storage.dart';

/// The master-password wrap of the data key.
///
/// Holds the salt, the iteration count and the sealed key as one unit, so the
/// three always move together — creating a vault and changing its password are
/// the same write, and neither can leave a salt that does not match its wrap.
class PasswordWrap {
  const PasswordWrap(this._storage);

  final VaultStorage _storage;

  Future<bool> exists() async {
    final wrapped = await _storage.read(VaultKeys.wrappedDek);
    return wrapped != null && wrapped.isNotEmpty;
  }

  /// Seals [dek] under a key derived from [password], replacing any existing
  /// wrap. A fresh salt every time, so the same password never reuses one.
  Future<void> store(String password, Uint8List dek) async {
    final salt = randomBytes(saltLength);
    final kek = await deriveKey(password, salt, defaultIterations);
    try {
      await _storage.write(VaultKeys.salt, base64Encode(salt));
      await _storage.write(VaultKeys.kdfIterations, '$defaultIterations');
      await _storage.write(VaultKeys.wrappedDek, seal(kek, dek));
    } finally {
      wipeBytes(kek);
    }
  }

  /// Returns the data key, or null when [password] is wrong or no wrap exists.
  Future<Uint8List?> unwrap(String password) async {
    final saltRaw = await _storage.read(VaultKeys.salt);
    final wrapped = await _storage.read(VaultKeys.wrappedDek);
    if (saltRaw == null || wrapped == null) return null;

    final stored = await _storage.read(VaultKeys.kdfIterations);
    final kek = await deriveKey(
      password,
      base64Decode(saltRaw),
      int.tryParse(stored ?? '') ?? defaultIterations,
    );

    try {
      return openSealed(kek, wrapped);
    } on VaultDecryptException {
      return null;
    } finally {
      wipeBytes(kek);
    }
  }

  Future<void> clear() async {
    await _storage.delete(VaultKeys.salt);
    await _storage.delete(VaultKeys.kdfIterations);
    await _storage.delete(VaultKeys.wrappedDek);
  }
}
