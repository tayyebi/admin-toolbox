import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../models/host.dart';

class HostRepository {
  final _uuid = const Uuid();

  Future<List<Host>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('hosts', orderBy: 'name ASC');
    return maps.map(Host.fromMap).toList();
  }

  Future<Host?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('hosts', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Host.fromMap(maps.first) : null;
  }

  Future<List<Host>> getByGroup(String groupId) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('hosts', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'name ASC');
    return maps.map(Host.fromMap).toList();
  }

  Future<List<Host>> getFavorites() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('hosts', where: 'favorite = 1', orderBy: 'name ASC');
    return maps.map(Host.fromMap).toList();
  }

  Future<List<Host>> search(String query) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'hosts',
      where: 'name LIKE ? OR hostname LIKE ? OR tags LIKE ? OR notes LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map(Host.fromMap).toList();
  }

  Future<Host> insert(Host host) async {
    final db = await AppDatabase.instance.database;
    final id = host.id.isEmpty || host.id == 'new' ? _uuid.v4() : host.id;
    final now = DateTime.now();

    final newHost = Host(
      id: id,
      name: host.name,
      hostname: host.hostname,
      port: host.port,
      groupId: host.groupId,
      identityId: host.identityId,
      connectionType: host.connectionType,
      tags: host.tags,
      notes: host.notes,
      favorite: host.favorite,
      metadata: host.metadata,
      status: host.status,
      lastSeen: host.lastSeen,
      monitoringPaused: host.monitoringPaused,
      connectTimeoutSeconds: host.connectTimeoutSeconds,
      createdAt: host.createdAt != DateTime(0) ? host.createdAt : now,
      updatedAt: now,
    );

    await db.insert('hosts', newHost.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newHost;
  }

  Future<void> update(Host host) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'hosts',
      host.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [host.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('hosts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> bulkDelete(List<String> ids) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('hosts', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

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
