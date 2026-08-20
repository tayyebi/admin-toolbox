import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'aead.dart';
import 'biometric_wrap.dart';
import 'legacy_vault.dart';
import 'password_wrap.dart';
import 'secure_random.dart';
import 'vault_exceptions.dart';
import 'vault_storage.dart';

/// Envelope encryption for everything secret the app stores.
///
/// The master password derives a key-encryption key via PBKDF2; that key only
/// wraps a random 32-byte data-encryption key (DEK), and the DEK encrypts the
/// records. So a password change rewraps one small blob rather than every
/// credential, and the DEK is in plaintext only in memory, only while unlocked.
///
/// Each way of releasing the DEK is its own wrap; this type picks one.
class EncryptionService {
  EncryptionService({VaultStorage storage = const SecureVaultStorage()})
      : password = PasswordWrap(storage),
        legacy = LegacyVault(storage),
        biometric = BiometricWrap(storage);

  static final EncryptionService instance = EncryptionService();

  final PasswordWrap password;
  final LegacyVault legacy;
  final BiometricWrap biometric;

  Uint8List? _dek;

  bool get isUnlocked => _dek != null;

  /// True once a master password has been set on this device.
  Future<bool> isInitialized() async => await password.exists() || await legacy.exists();

  /// Overwrites any existing vault, so callers must confirm first.
  Future<void> initialize(String masterPassword) async {
    final dek = randomBytes(keyLength);
    await password.store(masterPassword, dek);
    _adoptDek(dek);
  }

  /// Returns false when the password is wrong. Any other failure throws.
  Future<bool> unlock(String masterPassword) async {
    // No current-generation wrap means a v1 vault, verified by re-derivation.
    if (!await password.exists()) return _unlockLegacy(masterPassword);
    return _adoptDek(await password.unwrap(masterPassword));
  }

  Future<bool> unlockWithBiometricKey() async => _adoptDek(await biometric.release());

  void lock() => _adoptDek(null);

  /// Rewraps the DEK. Records are untouched — they are sealed under the DEK.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (!await unlock(currentPassword)) return false;
    await password.store(newPassword, requireDek());
    return true;
  }

  /// Output is `base64(nonce ‖ ciphertext ‖ tag)`.
  String encryptValue(String plaintext) => seal(requireDek(), utf8.encode(plaintext));

  String decryptValue(String ciphertext) => utf8.decode(openSealed(requireDek(), ciphertext));

  /// Permanently unrecoverable. Belongs behind an explicit confirmation.
  Future<void> reset() async {
    lock();
    await password.clear();
    await biometric.disable();
    await legacy.clear();
  }

  Uint8List requireDek() {
    final dek = _dek;
    if (dek == null) throw const VaultLockedException();
    return dek;
  }

  /// Takes ownership of a released key, wiping whatever it displaces — an
  /// unlock while already unlocked used to strand a live key on the heap.
  bool _adoptDek(Uint8List? dek) {
    final previous = _dek;
    if (previous != null) wipeBytes(previous);
    _dek = dek;
    return dek != null;
  }

  Future<bool> _unlockLegacy(String masterPassword) async {
    if (!await legacy.verifyPassword(masterPassword)) return false;

    // The migration pass still needs the v1 key, so it is cleared later.
    await initialize(masterPassword);
    return true;
  }
}
