import 'package:sqflite/sqflite.dart';

import '../../core/database/database.dart';
import 'identity_repository.dart';

/// How many hosts reference each identity, for the vault list and for
/// warning before a delete.
extension IdentityUsage on IdentityRepository {
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
}
