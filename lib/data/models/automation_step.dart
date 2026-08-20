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
