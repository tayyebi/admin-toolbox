import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../models/identity.dart';
import 'identity_secrets.dart';

export 'identity_migration.dart';
export 'identity_secrets.dart';
export 'identity_usage.dart';

class IdentityRepository {
  final _uuid = const Uuid();

  /// Public so the usage and migration extensions can reach it.
  final secrets = const IdentitySecrets();

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
    return Future.wait(maps.map(Identity.fromMap).map(secrets.decrypt));
  }

  Future<Identity?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('identities', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return secrets.decrypt(Identity.fromMap(maps.first));
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
      secrets.encrypt(record).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record;
  }

  Future<void> update(Identity identity) async {
    final db = await AppDatabase.instance.database;
    final record = identity.copyWith(updatedAt: DateTime.now(), cryptoVersion: 2);
    await db.update(
      'identities',
      secrets.encrypt(record).toMap(),
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
}
