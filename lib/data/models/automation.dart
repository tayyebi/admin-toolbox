import '../../core/utils/json_codec.dart';

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
class AutomationStep {
  const AutomationStep({
    required this.command,
    this.type = 'command',
    this.name,
    this.continueOnFailure = false,
    this.expectedExitCode = 0,
    this.timeout = const Duration(seconds: 60),
  });

  final String command;

  /// `command` today; reserved for `upload`, `check` and similar later.
  final String type;

  final String? name;

  /// When false, a failing step aborts the run and triggers rollback.
  final bool continueOnFailure;

  final int expectedExitCode;
  final Duration timeout;

  AutomationStep copyWith({
    String? command,
    String? type,
    String? name,
    bool? continueOnFailure,
    int? expectedExitCode,
    Duration? timeout,
  }) {
    return AutomationStep(
      command: command ?? this.command,
      type: type ?? this.type,
      name: name ?? this.name,
      continueOnFailure: continueOnFailure ?? this.continueOnFailure,
      expectedExitCode: expectedExitCode ?? this.expectedExitCode,
      timeout: timeout ?? this.timeout,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'command': command,
        if (name != null) 'name': name,
        'continue_on_failure': continueOnFailure,
        'expected_exit_code': expectedExitCode,
        'timeout_seconds': timeout.inSeconds,
      };

  factory AutomationStep.fromJson(Map<String, dynamic> json) {
    return AutomationStep(
      command: json['command'] as String? ?? '',
      type: json['type'] as String? ?? 'command',
      name: json['name'] as String?,
      continueOnFailure: json['continue_on_failure'] as bool? ?? false,
      expectedExitCode: json['expected_exit_code'] as int? ?? 0,
      timeout: Duration(seconds: json['timeout_seconds'] as int? ?? 60),
    );
  }

  /// Substitutes `{{name}}` placeholders, matching `Command.interpolate`.
  String interpolate(Map<String, String> variables) {
    var result = command;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
