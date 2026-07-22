import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  final _secureStorage = const FlutterSecureStorage();
  static const _keyStorageKey = 'master_encryption_key';
  static const _saltStorageKey = 'master_encryption_salt';

  encrypt.Key? _masterKey;
  encrypt.IV? _masterIv;

  Future<bool> isMasterKeySet() async {
    final key = await _secureStorage.read(key: _keyStorageKey);
    return key != null && key.isNotEmpty;
  }

  Future<void> setMasterPassword(String password) async {
    final salt = encrypt.IV.fromSecureRandom(16);
    final derivedKey = _deriveKey(password, salt);

    await _secureStorage.write(key: _keyStorageKey, value: derivedKey.base64);
    await _secureStorage.write(key: _saltStorageKey, value: salt.base64);

    _masterKey = derivedKey;
    _masterIv = encrypt.IV.fromSecureRandom(16);
  }

  Future<bool> verifyMasterPassword(String password) async {
    final storedKey = await _secureStorage.read(key: _keyStorageKey);
    final storedSalt = await _secureStorage.read(key: _saltStorageKey);

    if (storedKey == null || storedSalt == null) return false;

    final salt = encrypt.IV.fromBase64(storedSalt);
    final derivedKey = _deriveKey(password, salt);

    return derivedKey.base64 == storedKey;
  }

  Future<String?> getMasterKey() async {
    if (_masterKey != null) return _masterKey!.base64;
    final key = await _secureStorage.read(key: _keyStorageKey);
    if (key != null) {
      _masterKey = encrypt.Key.fromBase64(key);
    }
    return key;
  }

  encrypt.Key _deriveKey(String password, encrypt.IV salt) {
    final bytes = utf8.encode(password) + salt.bytes;
    final hash = sha256.convert(bytes);
    return encrypt.Key.fromUtf8(hash.toString().substring(0, 32));
  }

  Future<String> encryptValue(String plaintext) async {
    final keyStr = await getMasterKey();
    if (keyStr == null) {
      throw StateError('Master key not set. Call setMasterPassword first.');
    }

    final key = encrypt.Key.fromBase64(keyStr);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }

  Future<String> decryptValue(String ciphertext) async {
    final keyStr = await getMasterKey();
    if (keyStr == null) {
      throw StateError('Master key not set. Call setMasterPassword first.');
    }

    final key = encrypt.Key.fromBase64(keyStr);
    final combined = base64Decode(ciphertext);

    final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encryptedBytes = combined.sublist(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    return encrypter.decryptBytes(encrypt.Encrypted(Uint8List.fromList(encryptedBytes)), iv: iv);
  }

  Future<String> hashValue(String value) async {
    final bytes = utf8.encode(value);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  String generatePassword({int length = 24}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?';
    final random = encrypt.IV.fromSecureRandom(length);
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[random.bytes[i] % chars.length]);
    }
    return buffer.toString();
  }
}
