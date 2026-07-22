import 'package:uuid/uuid.dart';
import '../../core/crypto/encryption.dart';
import '../../core/database/database.dart';
import '../models/identity.dart';

class IdentityRepository {
  final _uuid = const Uuid();
  final _encryption = EncryptionService.instance;

  Future<List<Identity>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', orderBy: 'name ASC');
    final identities = maps.map(Identity.fromMap).toList();
    return Future.wait(identities.map(_decryptSecrets));
  }

  Future<Identity?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return _decryptSecrets(Identity.fromMap(maps.first));
  }

  Future<Identity> insert(Identity identity) async {
    final db = await AppDatabase.instance.database;
    final id = identity.id.isEmpty ? _uuid.v4() : identity.id;
    final now = DateTime.now();

    final newIdentity = Identity(
      id: id,
      name: identity.name,
      type: identity.type,
      username: identity.username,
      password: identity.password,
      privateKey: identity.privateKey,
      passphrase: identity.passphrase,
      certificate: identity.certificate,
      createdAt: now,
      updatedAt: now,
    );

    final encrypted = await _encryptSecrets(newIdentity);
    await db.insert('identities', encrypted.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newIdentity;
  }

  Future<void> update(Identity identity) async {
    final db = await AppDatabase.instance.database;
    final updated = identity.copyWith(updatedAt: DateTime.now());
    final encrypted = await _encryptSecrets(updated);
    await db.update('identities', encrypted.toMap(), where: 'id = ?', whereArgs: [updated.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('identities', where: 'id = ?', whereArgs: [id]);
  }

  Future<Identity> _encryptSecrets(Identity identity) async {
    String? encryptedPassword;
    String? encryptedKey;
    String? encryptedPassphrase;

    if (identity.password != null && identity.password!.isNotEmpty) {
      encryptedPassword = await _encryption.encryptValue(identity.password!);
    }
    if (identity.privateKey != null && identity.privateKey!.isNotEmpty) {
      encryptedKey = await _encryption.encryptValue(identity.privateKey!);
    }
    if (identity.passphrase != null && identity.passphrase!.isNotEmpty) {
      encryptedPassphrase = await _encryption.encryptValue(identity.passphrase!);
    }

    return identity.copyWith(
      password: encryptedPassword,
      privateKey: encryptedKey,
      passphrase: encryptedPassphrase,
    );
  }

  Future<Identity> _decryptSecrets(Identity identity) async {
    String? decryptedPassword;
    String? decryptedKey;
    String? decryptedPassphrase;

    if (identity.password != null && identity.password!.isNotEmpty) {
      try {
        decryptedPassword = await _encryption.decryptValue(identity.password!);
      } catch (_) {
        decryptedPassword = identity.password;
      }
    }
    if (identity.privateKey != null && identity.privateKey!.isNotEmpty) {
      try {
        decryptedKey = await _encryption.decryptValue(identity.privateKey!);
      } catch (_) {
        decryptedKey = identity.privateKey;
      }
    }
    if (identity.passphrase != null && identity.passphrase!.isNotEmpty) {
      try {
        decryptedPassphrase = await _encryption.decryptValue(identity.passphrase!);
      } catch (_) {
        decryptedPassphrase = identity.passphrase;
      }
    }

    return identity.copyWith(
      password: decryptedPassword,
      privateKey: decryptedKey,
      passphrase: decryptedPassphrase,
    );
  }
}
