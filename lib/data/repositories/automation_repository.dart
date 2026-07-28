import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../models/automation.dart';

class AutomationRepository {
  final _uuid = const Uuid();

  Future<List<Automation>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('automations', orderBy: 'name ASC');
    return maps.map(Automation.fromMap).toList();
  }

  Future<Automation?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('automations', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Automation.fromMap(maps.first) : null;
  }

  Future<List<Automation>> getByCategory(String category) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'automations',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return maps.map(Automation.fromMap).toList();
  }

  Future<Automation> insert(Automation automation) async {
    final db = await AppDatabase.instance.database;
    final id = automation.id.isEmpty ? _uuid.v4() : automation.id;
    final now = DateTime.now();

    final newAutomation = Automation(
      id: id,
      name: automation.name,
      description: automation.description,
      category: automation.category,
      parameters: automation.parameters,
      steps: automation.steps,
      rollbackSteps: automation.rollbackSteps,
      validation: automation.validation,
      outputParser: automation.outputParser,
      favorite: automation.favorite,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('automations', newAutomation.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newAutomation;
  }

  Future<void> update(Automation automation) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'automations',
      automation.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [automation.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('automations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(String id) async {
    final automation = await getById(id);
    if (automation != null) {
      await update(automation.copyWith(favorite: !automation.favorite));
    }
  }
}
