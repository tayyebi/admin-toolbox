import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Thrown when the vault is asked to encrypt or decrypt while locked.
class VaultLockedException implements Exception {
  const VaultLockedException();
  @override
  String toString() => 'Vault is locked';
}

/// Thrown when a stored secret fails to decrypt — wrong key, or the ciphertext
/// was truncated or tampered with. Never swallow this: returning ciphertext in
/// place of a plaintext credential would hand a base64 blob to an SSH server.
class VaultDecryptException implements Exception {
  const VaultDecryptException(this.message);
  final String message;
  @override
  String toString() => 'Failed to decrypt vault record: $message';
}

/// Envelope encryption for everything secret the app stores.
///
/// The master password derives a key-encryption key (KEK) via PBKDF2; the KEK
/// only ever wraps a random 32-byte data-encryption key (DEK), and the DEK
/// encrypts the actual records. Two consequences matter:
///
///  * Changing the master password rewraps one small blob instead of
///    re-encrypting every credential in the database.
///  * The DEK exists in plaintext only in memory, only while unlocked. Secure
///    storage holds the *wrapped* DEK, so possession of the device file system
///    without the password (or a biometric match) yields nothing.
///
/// Records use AES-256-GCM, so tampering fails loudly instead of decrypting to
/// plausible garbage the way the previous unauthenticated CBC scheme did.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Current-generation keys.
  static const _kSalt = 'vault.kdf_salt';
  static const _kWrappedDek = 'vault.wrapped_dek';
  static const _kBiometricDek = 'vault.biometric_dek';
  static const _kKdfIterations = 'vault.kdf_iterations';

  // Pre-migration keys, read only so v1 vaults can be upgraded in place.
  static const _kLegacyKey = 'master_encryption_key';
  static const _kLegacySalt = 'master_encryption_salt';

  /// OWASP's 2023 floor for PBKDF2-HMAC-SHA256. Persisted per vault so the
  /// figure can be raised later without locking out existing users.
  static const int defaultIterations = 210000;

  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _keyLength = 32;
  static const int _macBits = 128;

  Uint8List? _dek;

  bool get isUnlocked => _dek != null;

  /// True once a master password has been set on this device.
  Future<bool> isInitialized() async {
    final wrapped = await _storage.read(key: _kWrappedDek);
    if (wrapped != null && wrapped.isNotEmpty) return true;
    return hasLegacyVault();
  }

  /// A v1 vault: the derived key itself sat in secure storage, so anything
  /// with file system access could read it. Upgraded on first unlock.
  Future<bool> hasLegacyVault() async {
    final legacy = await _storage.read(key: _kLegacyKey);
    return legacy != null && legacy.isNotEmpty;
  }

  /// Creates a vault. Overwrites any existing one, so callers must confirm
  /// first — every stored credential becomes unreadable.
  Future<void> initialize(String password) async {
    final salt = _randomBytes(_saltLength);
    final dek = _randomBytes(_keyLength);
    final kek = await _deriveKey(password, salt, defaultIterations);

    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _storage.write(key: _kKdfIterations, value: '$defaultIterations');
    await _storage.write(key: _kWrappedDek, value: _seal(kek, dek));

    _wipe(kek);
    _dek = dek;
  }

  /// Returns false when the password is wrong. Any other failure throws.
  Future<bool> unlock(String password) async {
    final saltRaw = await _storage.read(key: _kSalt);
    final wrapped = await _storage.read(key: _kWrappedDek);

    if (saltRaw == null || wrapped == null) {
      // v1 vault: the key is stored directly, verified by re-derivation.
      return _unlockLegacy(password);
    }

    final iterations =
        int.tryParse(await _storage.read(key: _kKdfIterations) ?? '') ?? defaultIterations;
    final kek = await _deriveKey(password, base64Decode(saltRaw), iterations);

    try {
      _dek = _open(kek, wrapped);
      return true;
    } on VaultDecryptException {
      return false;
    } finally {
      _wipe(kek);
    }
  }

  /// Releases the DEK after the user has passed a biometric check.
  ///
  /// The biometric prompt itself is `local_auth`'s job; this only holds the
  /// copy of the DEK that unlock releases. That makes biometric unlock a
  /// convenience gate rather than a second independent secret — which is the
  /// honest description of what any Flutter app can offer here.
  Future<bool> unlockWithBiometricKey() async {
    final stored = await _storage.read(key: _kBiometricDek);
    if (stored == null || stored.isEmpty) return false;
    _dek = base64Decode(stored);
    return true;
  }

  /// Enables biometric unlock by parking a DEK copy in secure storage.
  /// Requires the vault to already be unlocked.
  Future<void> enableBiometricUnlock() async {
    final dek = _requireDek();
    await _storage.write(key: _kBiometricDek, value: base64Encode(dek));
  }

  Future<void> disableBiometricUnlock() async {
    await _storage.delete(key: _kBiometricDek);
  }

  Future<bool> isBiometricUnlockConfigured() async {
    final stored = await _storage.read(key: _kBiometricDek);
    return stored != null && stored.isNotEmpty;
  }

  void lock() {
    final dek = _dek;
    if (dek != null) _wipe(dek);
    _dek = null;
  }

  /// Rewraps the DEK under a key derived from [newPassword]. Stored records are
  /// untouched, because they are encrypted under the DEK, not the password.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (!await unlock(currentPassword)) return false;

    final dek = _requireDek();
    final salt = _randomBytes(_saltLength);
    final kek = await _deriveKey(newPassword, salt, defaultIterations);

    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _storage.write(key: _kKdfIterations, value: '$defaultIterations');
    await _storage.write(key: _kWrappedDek, value: _seal(kek, dek));

    _wipe(kek);
    return true;
  }

  /// Encrypts with the in-memory DEK. Output is
  /// `base64(nonce ‖ ciphertext ‖ tag)`.
  String encryptValue(String plaintext) => _seal(_requireDek(), utf8.encode(plaintext));

  String decryptValue(String ciphertext) => utf8.decode(_open(_requireDek(), ciphertext));

  /// Reads a record written by the v1 AES-CBC scheme, used only during
  /// migration. The v1 key is unauthenticated, so a wrong key yields garbage
  /// rather than an error — callers must sanity-check the result.
  Future<String?> decryptLegacyValue(String ciphertext) async {
    final legacyKeyRaw = await _storage.read(key: _kLegacyKey);
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

      // Strip PKCS#7 padding.
      final padLength = out.isEmpty ? 0 : out.last;
      if (padLength <= 0 || padLength > 16 || padLength > out.length) return null;
      return utf8.decode(out.sublist(0, out.length - padLength));
    } catch (_) {
      return null;
    }
  }

  /// Discards v1 material once every record has been re-encrypted.
  Future<void> clearLegacyVault() async {
    await _storage.delete(key: _kLegacySalt);
    await _storage.delete(key: _kLegacyKey);
  }

  /// Destroys the vault. Every encrypted record becomes permanently
  /// unrecoverable, so this belongs behind an explicit confirmation.
  Future<void> reset() async {
    lock();
    await _storage.delete(key: _kSalt);
    await _storage.delete(key: _kWrappedDek);
    await _storage.delete(key: _kKdfIterations);
    await _storage.delete(key: _kBiometricDek);
    await clearLegacyVault();
  }

  String generatePassword({int length = 24}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?';
    final bytes = _randomBytes(length);
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[bytes[i] % chars.length]);
    }
    return buffer.toString();
  }

  // --- internals -----------------------------------------------------------

  Future<bool> _unlockLegacy(String password) async {
    final storedKey = await _storage.read(key: _kLegacyKey);
    final storedSalt = await _storage.read(key: _kLegacySalt);
    if (storedKey == null || storedSalt == null) return false;

    // Reproduces the v1 derivation exactly, purely to verify the password.
    final digest = sha256OfBytes(
      Uint8List.fromList(utf8.encode(password) + base64Decode(storedSalt)),
    );
    final legacyDerived = base64Encode(utf8.encode(_hex(digest).substring(0, 32)));
    if (legacyDerived != storedKey) return false;

    // Password is correct — promote the vault to the current scheme. Records
    // are re-encrypted lazily by the migration pass, which needs the v1 key
    // still present, so it is cleared later rather than here.
    await initialize(password);
    return true;
  }

  Uint8List _requireDek() {
    final dek = _dek;
    if (dek == null) throw const VaultLockedException();
    return dek;
  }

  String _seal(Uint8List key, List<int> plaintext) {
    final nonce = _randomBytes(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)));
    final body = cipher.process(Uint8List.fromList(plaintext));
    return base64Encode(Uint8List.fromList(nonce + body));
  }

  Uint8List _open(Uint8List key, String sealed) {
    late final Uint8List combined;
    try {
      combined = base64Decode(sealed);
    } catch (_) {
      throw const VaultDecryptException('value is not valid base64');
    }
    if (combined.length <= _nonceLength + (_macBits ~/ 8)) {
      throw const VaultDecryptException('value is too short to be a sealed record');
    }

    final nonce = Uint8List.fromList(combined.sublist(0, _nonceLength));
    final body = Uint8List.fromList(combined.sublist(_nonceLength));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)));

    try {
      return cipher.process(body);
    } on InvalidCipherTextException {
      throw const VaultDecryptException('authentication tag mismatch');
    } catch (e) {
      throw VaultDecryptException('$e');
    }
  }

  /// PBKDF2 runs off the UI isolate: at 210k iterations it blocks for around a
  /// second on mid-range hardware, which would drop frames on the lock screen.
  Future<Uint8List> _deriveKey(String password, Uint8List salt, int iterations) {
    return compute(
      _pbkdf2,
      _Pbkdf2Request(password: password, salt: salt, iterations: iterations),
    );
  }

  Uint8List _randomBytes(int length) {
    final random = math.Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  void _wipe(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  static Uint8List sha256OfBytes(Uint8List input) => SHA256Digest().process(input);

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

@immutable
class _Pbkdf2Request {
  const _Pbkdf2Request({
    required this.password,
    required this.salt,
    required this.iterations,
  });

  final String password;
  final Uint8List salt;
  final int iterations;
}

/// Top-level so it can run in a background isolate via [compute].
Uint8List _pbkdf2(_Pbkdf2Request request) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(request.salt, request.iterations, 32));
  return derivator.process(Uint8List.fromList(utf8.encode(request.password)));
}
