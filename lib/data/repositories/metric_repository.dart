import 'package:sqflite/sqflite.dart';
import '../../core/database/database.dart';
import '../models/metric.dart';

class MetricRepository {

  Future<List<Metric>> getForHost(String hostId, String collectorId, {int limit = 100}) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'metrics',
      where: 'host_id = ? AND collector_id = ?',
      whereArgs: [hostId, collectorId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(Metric.fromMap).toList();
  }

  Future<List<Metric>> getLatestForHost(String hostId) async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT collector_id 
      FROM metrics 
      WHERE host_id = ?
    ''', [hostId]);

    final metrics = <Metric>[];
    for (final row in result) {
      final maps = await db.query(
        'metrics',
        where: 'host_id = ? AND collector_id = ?',
        whereArgs: [hostId, row['collector_id']],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (maps.isNotEmpty) {
        metrics.add(Metric.fromMap(maps.first));
      }
    }
    return metrics;
  }

  Future<void> insert(Metric metric) async {
    final db = await AppDatabase.instance.database;
    await db.insert('metrics', metric.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertBatch(List<Metric> metrics) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final metric in metrics) {
      batch.insert('metrics', metric.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<MetricSeries> getSeries(String hostId, String collectorId, {int limit = 60}) async {
    final metrics = await getForHost(hostId, collectorId, limit: limit);
    return MetricSeries(
      hostId: hostId,
      collectorId: collectorId,
      metrics: metrics.reversed.toList(),
    );
  }

  Future<void> deleteOlderThan(Duration retention) async {
    final db = await AppDatabase.instance.database;
    final cutoff = DateTime.now().subtract(retention).toIso8601String();
    await db.delete('metrics', where: 'timestamp < ?', whereArgs: [cutoff]);
  }
}
