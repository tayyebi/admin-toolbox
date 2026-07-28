class Automation {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final Map<String, String>? parameters;
  final List<AutomationStep> steps;
  final List<AutomationStep>? rollbackSteps;
  final String? validation;
  final String? outputParser;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Automation({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.parameters,
    required this.steps,
    this.rollbackSteps,
    this.validation,
    this.outputParser,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'parameters': _encodeMap(parameters),
      'steps': _encodeSteps(steps),
      'rollback_steps': rollbackSteps != null ? _encodeSteps(rollbackSteps!) : null,
      'validation': validation,
      'output_parser': outputParser,
      'favorite': favorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Automation.fromMap(Map<String, dynamic> map) {
    return Automation(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      parameters: _decodeMap(map['parameters'] as String?),
      steps: _decodeSteps(map['steps'] as String?),
      rollbackSteps: _decodeSteps(map['rollback_steps'] as String?),
      validation: map['validation'] as String?,
      outputParser: map['output_parser'] as String?,
      favorite: (map['favorite'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Automation copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    Map<String, String>? parameters,
    List<AutomationStep>? steps,
    List<AutomationStep>? rollbackSteps,
    String? validation,
    String? outputParser,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Automation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      parameters: parameters ?? this.parameters,
      steps: steps ?? this.steps,
      rollbackSteps: rollbackSteps ?? this.rollbackSteps,
      validation: validation ?? this.validation,
      outputParser: outputParser ?? this.outputParser,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _encodeMap(Map<String, String>? map) {
    if (map == null) return '';
    return map.entries.map((e) => '${e.key}=${e.value}').join(',');
  }

  static Map<String, String>? _decodeMap(String? str) {
    if (str == null || str.isEmpty) return null;
    final map = <String, String>{};
    for (final pair in str.split(',')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        map[parts[0].trim()] = parts[1].trim();
      }
    }
    return map;
  }

  static String _encodeSteps(List<AutomationStep> steps) {
    return steps.map((s) => '${s.type}|${s.command}').join('\n');
  }

  static List<AutomationStep> _decodeSteps(String? str) {
    if (str == null || str.isEmpty) return [];
    return str.split('\n').map((line) {
      final parts = line.split('|');
      return AutomationStep(
        type: parts.isNotEmpty ? parts[0] : 'command',
        command: parts.length > 1 ? parts[1] : line,
      );
    }).toList();
  }
}

class AutomationStep {
  final String type;
  final String command;

  const AutomationStep({required this.type, required this.command});
}
