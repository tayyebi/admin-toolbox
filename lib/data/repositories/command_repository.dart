import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../models/command.dart';

class CommandRepository {
  final _uuid = const Uuid();

  Future<List<Command>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('commands', orderBy: 'name ASC');
    return maps.map(Command.fromMap).toList();
  }

  Future<Command?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('commands', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Command.fromMap(maps.first) : null;
  }

  Future<List<Command>> getByCategory(String category) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'commands',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return maps.map(Command.fromMap).toList();
  }

  Future<List<Command>> getFavorites() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('commands', where: 'favorite = 1', orderBy: 'name ASC');
    return maps.map(Command.fromMap).toList();
  }

  Future<List<Command>> search(String query) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'commands',
      where: 'name LIKE ? OR command LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map(Command.fromMap).toList();
  }

  Future<Command> insert(Command command) async {
    final db = await AppDatabase.instance.database;
    final id = command.id.isEmpty ? _uuid.v4() : command.id;
    final now = DateTime.now();

    final newCommand = Command(
      id: id,
      name: command.name,
      command: command.command,
      description: command.description,
      category: command.category,
      variables: command.variables,
      favorite: command.favorite,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('commands', newCommand.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newCommand;
  }

  Future<void> update(Command command) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'commands',
      command.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [command.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('commands', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(String id) async {
    final command = await getById(id);
    if (command != null) {
      await update(command.copyWith(favorite: !command.favorite));
    }
  }
}
