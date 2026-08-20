import '../../core/database/database.dart';
import 'host_repository.dart';

/// Flags and liveness that change without the user editing the host.
extension HostState on HostRepository {
  Future<void> updateStatus(String id, String status) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'hosts',
      {
        'status': status,
        'last_seen': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleFavorite(String id) async {
    final db = await AppDatabase.instance.database;
    final host = await getById(id);
    if (host != null) {
      await db.update(
        'hosts',
        {'favorite': host.favorite ? 0 : 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// A paused host is skipped by the background monitoring loop, but the
  /// status it was last seen at is kept until the next real connection.
  Future<void> toggleMonitoringPaused(String id) async {
    final db = await AppDatabase.instance.database;
    final host = await getById(id);
    if (host != null) {
      await db.update(
        'hosts',
        {
          'monitoring_paused': host.monitoringPaused ? 0 : 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
