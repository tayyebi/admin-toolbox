import 'step_outcome.dart';

class StepResult {
  StepResult({
    required this.stepIndex,
    required this.command,
    this.outcome = StepOutcome.pending,
    this.exitCode,
    this.output = '',
    this.duration = Duration.zero,
  });

  final int stepIndex;
  final String command;
  StepOutcome outcome;
  int? exitCode;
  String output;
  Duration duration;

  Map<String, dynamic> toJson() => {
        'step': stepIndex,
        'command': command,
        'outcome': outcome.name,
        'exit_code': exitCode,
        'output': output,
        'duration_ms': duration.inMilliseconds,
      };
}
