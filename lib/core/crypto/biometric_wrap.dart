import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'vault_keys.dart';
import 'vault_storage.dart';

/// Biometric unlock, today: a copy of the data key parked in secure storage
/// behind an OS prompt.
///
/// This is a convenience gate, not a second independent secret — `local_auth`
/// verifies the human, and nothing cryptographically binds that check to the
/// key released here. Anything that can read secure storage gets the data key
/// without a password. Replacing this with a keystore-held wrap is tracked
/// separately; the interface is shaped so that swap touches only this file.
class BiometricWrap {
  const BiometricWrap(this._storage);

  final VaultStorage _storage;

  Future<bool> isConfigured() async {
    final stored = await _storage.read(VaultKeys.biometricDek);
    return stored != null && stored.isNotEmpty;
  }

  /// Requires an already-unlocked vault, since it stores the live key.
  Future<void> enable(Uint8List dek) =>
      _storage.write(VaultKeys.biometricDek, base64Encode(dek));

  Future<void> disable() => _storage.delete(VaultKeys.biometricDek);

  /// Returns null when biometric unlock is not configured.
  Future<Uint8List?> release() async {
    final stored = await _storage.read(VaultKeys.biometricDek);
    if (stored == null || stored.isEmpty) return null;
    return base64Decode(stored);
  }
}
