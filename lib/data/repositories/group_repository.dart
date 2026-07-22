import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../models/group.dart';

class GroupRepository {
  final _uuid = const Uuid();

  Future<List<Group>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('groups', orderBy: 'name ASC');
    return maps.map(Group.fromMap).toList();
  }

  Future<Group?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('groups', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Group.fromMap(maps.first) : null;
  }

  Future<List<Group>> getByParent(String? parentId) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'groups',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId != null ? [parentId] : null,
      orderBy: 'name ASC',
    );
    return maps.map(Group.fromMap).toList();
  }

  Future<List<Group>> getChildren(String id) async {
    return getByParent(id);
  }

  Future<Group> insert(Group group) async {
    final db = await AppDatabase.instance.database;
    final id = group.id.isEmpty ? _uuid.v4() : group.id;
    final now = DateTime.now();

    final newGroup = Group(
      id: id,
      name: group.name,
      parentId: group.parentId,
      description: group.description,
      color: group.color,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('groups', newGroup.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newGroup;
  }

  Future<void> update(Group group) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'groups',
      group.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getGroupTree() async {
    final groups = await getAll();
    return _buildTree(groups, null);
  }

  List<Map<String, dynamic>> _buildTree(List<Group> groups, String? parentId) {
    final children = <Map<String, dynamic>>[];
    for (final group in groups.where((g) => g.parentId == parentId)) {
      children.add({
        'group': group,
        'children': _buildTree(groups, group.id),
      });
    }
    return children;
  }
}
