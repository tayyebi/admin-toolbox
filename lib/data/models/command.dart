class Command {
  final String id;
  final String name;
  final String command;
  final String? description;
  final String? category;
  final List<String>? variables;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Command({
    required this.id,
    required this.name,
    required this.command,
    this.description,
    this.category,
    this.variables,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'command': command,
      'description': description,
      'category': category,
      'variables': variables?.join(','),
      'favorite': favorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Command.fromMap(Map<String, dynamic> map) {
    return Command(
      id: map['id'] as String,
      name: map['name'] as String,
      command: map['command'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      variables: _parseList(map['variables'] as String?),
      favorite: (map['favorite'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static List<String>? _parseList(String? str) {
    if (str == null || str.isEmpty) return null;
    return str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  String interpolate(Map<String, String> vars) {
    var result = command;
    for (final entry in vars.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
