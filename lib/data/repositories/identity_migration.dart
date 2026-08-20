import '../../core/database/database.dart';
import '../models/identity.dart';
import 'identity_repository.dart';

/// The v1 → v2 re-encryption pass's view of the table.
extension IdentityMigration on IdentityRepository {
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
      secrets.encrypt(record).toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }
}
