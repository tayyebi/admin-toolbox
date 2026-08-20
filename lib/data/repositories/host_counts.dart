import 'package:sqflite/sqflite.dart';

import '../../core/database/database.dart';
import 'host_repository.dart';

extension HostCounts on HostRepository {
  Future<Map<String, int>> getStatusCounts() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT status, COUNT(*) as count FROM hosts GROUP BY status');
    final counts = <String, int>{};
    for (final row in result) {
      counts[row['status'] as String] = row['count'] as int;
    }
    return counts;
  }

  Future<int> getCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM hosts');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
