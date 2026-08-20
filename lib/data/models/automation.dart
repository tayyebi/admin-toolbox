import '../../core/utils/json_codec.dart';

import 'automation_step.dart';

export 'automation_copy.dart';
export 'automation_step.dart';

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
      'parameters': encodeStringMap(parameters),
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
      parameters: decodeStringMap(map['parameters'] as String?),
      steps: _decodeSteps(map['steps'] as String?),
      rollbackSteps: _decodeSteps(map['rollback_steps'] as String?),
      validation: map['validation'] as String?,
      outputParser: map['output_parser'] as String?,
      favorite: (map['favorite'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static String _encodeSteps(List<AutomationStep> steps) {
    return encodeObjectList(steps.map((s) => s.toJson()).toList());
  }

  static List<AutomationStep> _decodeSteps(String? str) {
    if (str == null || str.isEmpty) return const [];

    // Rows written before the JSON migration used `type|command` per line.
    if (!str.trimLeft().startsWith('[')) {
      return str
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final separator = line.indexOf('|');
            if (separator < 0) return AutomationStep(command: line);
            return AutomationStep(
              type: line.substring(0, separator),
              command: line.substring(separator + 1),
            );
          })
          .toList();
    }

    return decodeObjectList(str).map(AutomationStep.fromJson).toList();
  }
}

/// One step of a procedure.
