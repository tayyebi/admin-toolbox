import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/encryption.dart';
import '../../core/database/database.dart';
import '../../core/utils/logger.dart';
import '../models/identity.dart';

class IdentityRepository {
  final _uuid = const Uuid();
  final _encryption = EncryptionService.instance;

  /// Identities with secrets still sealed.
  ///
  /// The vault list only needs names, key types and fingerprints, none of
  /// which are secret — so listing never decrypts, and never needs the vault
  /// open. Call [getById] when a credential is actually about to be used.
  Future<List<Identity>> getAllRedacted() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', orderBy: 'name ASC');
    return maps.map(Identity.fromMap).map((i) => i.redacted()).toList();
  }

  /// Identities with secrets decrypted. Requires an unlocked vault.
  Future<List<Identity>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', orderBy: 'name ASC');
    return Future.wait(maps.map(Identity.fromMap).map(_decryptSecrets));
  }

  Future<Identity?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return _decryptSecrets(Identity.fromMap(maps.first));
  }

  Future<Identity?> getByIdRedacted(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Identity.fromMap(maps.first).redacted();
  }

  Future<Identity> insert(Identity identity) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    final record = identity.copyWith(
      id: identity.id.isEmpty ? _uuid.v4() : identity.id,
      cryptoVersion: 2,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'identities',
      _encryptSecrets(record).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record;
  }

  Future<void> update(Identity identity) async {
    final db = await AppDatabase.instance.database;
    final record = identity.copyWith(updatedAt: DateTime.now(), cryptoVersion: 2);
    await db.update(
      'identities',
      _encryptSecrets(record).toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('identities', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markUsed(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'identities',
      {'last_used_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// How many hosts reference each identity, for the vault list and for
  /// warning before a delete.
  Future<Map<String, int>> getHostUsageCounts() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT identity_id, COUNT(*) AS count FROM hosts '
      'WHERE identity_id IS NOT NULL GROUP BY identity_id',
    );
    return {
      for (final row in rows) row['identity_id'] as String: row['count'] as int,
    };
  }

  Future<int> getHostUsageCount(String identityId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM hosts WHERE identity_id = ?',
      [identityId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Rows still sealed with the v1 AES-CBC scheme.
  Future<List<Identity>> getPendingMigration() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', where: 'crypto_version < 2');
    return maps.map(Identity.fromMap).toList();
  }

  /// Rewrites a v1 row under the current scheme. [plaintext] must already have
  /// been recovered by the migration pass.
  Future<void> rewriteMigrated(Identity plaintext) async {
    final db = await AppDatabase.instance.database;
    final record = plaintext.copyWith(cryptoVersion: 2, updatedAt: DateTime.now());
    await db.update(
      'identities',
      _encryptSecrets(record).toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Identity _encryptSecrets(Identity identity) {
    return identity.copyWith(
      password: _sealOrNull(identity.password),
      privateKey: _sealOrNull(identity.privateKey),
      passphrase: _sealOrNull(identity.passphrase),
    );
  }

  Future<Identity> _decryptSecrets(Identity identity) async {
    // A v1 row is readable only through the legacy path; the migration pass
    // rewrites it, but a read may arrive first.
    if (identity.needsMigration) {
      return identity.copyWith(
        password: await _openLegacyOrNull(identity.password),
        privateKey: await _openLegacyOrNull(identity.privateKey),
        passphrase: await _openLegacyOrNull(identity.passphrase),
      );
    }

    return identity.copyWith(
      password: _openOrNull(identity.password),
      privateKey: _openOrNull(identity.privateKey),
      passphrase: _openOrNull(identity.passphrase),
    );
  }

  String? _sealOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return _encryption.encryptValue(value);
  }

  /// Decryption failure propagates.
  ///
  /// The previous implementation caught the error and returned the ciphertext,
  /// which meant a corrupt record was handed to `SSHClient` as a password —
  /// a silent auth failure at best, and a base64 blob in a server's auth log
  /// at worst. A broken credential must surface as an error.
  String? _openOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return _encryption.decryptValue(value);
  }

  Future<String?> _openLegacyOrNull(String? value) async {
    if (value == null || value.isEmpty) return null;
    final plaintext = await _encryption.decryptLegacyValue(value);
    if (plaintext == null) {
      logWarning('Legacy credential could not be decrypted; re-enter it in the vault');
      throw const VaultDecryptException('legacy record is unreadable');
    }
    return plaintext;
  }
}
