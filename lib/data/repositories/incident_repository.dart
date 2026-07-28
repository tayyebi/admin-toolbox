import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../models/incident.dart';

class IncidentRepository {
  final _uuid = const Uuid();

  Future<List<Incident>> getAll({String? status}) async {
    final db = await AppDatabase.instance.database;
    final where = status != null ? 'status = ?' : null;
    final whereArgs = status != null ? [status] : null;
    final maps = await db.query(
      'incidents',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map(Incident.fromMap).toList();
  }

  Future<Incident?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('incidents', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Incident.fromMap(maps.first) : null;
  }

  Future<Incident> insert(Incident incident) async {
    final db = await AppDatabase.instance.database;
    final id = incident.id.isEmpty ? _uuid.v4() : incident.id;
    final newIncident = Incident(
      id: id,
      title: incident.title,
      description: incident.description,
      status: incident.status,
      severity: incident.severity,
      affectedHosts: incident.affectedHosts,
      timeline: incident.timeline,
      resolution: incident.resolution,
      createdAt: incident.createdAt,
      updatedAt: incident.updatedAt,
      resolvedAt: incident.resolvedAt,
    );
    await db.insert('incidents', newIncident.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newIncident;
  }

  Future<void> update(Incident incident) async {
    final db = await AppDatabase.instance.database;
    await db.update('incidents', incident.toMap(), where: 'id = ?', whereArgs: [incident.id]);
  }

  Future<void> resolve(String id, String resolution) async {
    final db = await AppDatabase.instance.database;
    await db.update('incidents', {
      'status': 'resolved',
      'resolution': resolution,
      'resolved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }
}
