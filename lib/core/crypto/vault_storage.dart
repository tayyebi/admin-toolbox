import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The vault's persistence seam.
///
/// Exists so the envelope logic can be tested. `flutter_secure_storage` needs a
/// platform channel, which is why `EncryptionService` had no unit tests at all;
/// injecting this lets every wrap and unwrap path run under `flutter test`.
abstract class VaultStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android `EncryptedSharedPreferences`, backed by the platform keystore.
class SecureVaultStorage implements VaultStorage {
  const SecureVaultStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Test double. Deliberately not const-constructible — each test wants its own.
class InMemoryVaultStorage implements VaultStorage {
  final _values = <String, String>{};

  Map<String, String> get snapshot => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
