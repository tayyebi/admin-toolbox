import 'step_result.dart';

class HostRunResult {
  HostRunResult({required this.hostId, required this.hostName});

  final String hostId;
  final String hostName;
  final List<StepResult> steps = [];

  bool succeeded = false;
  bool rolledBack = false;
  String? error;

  Map<String, dynamic> toJson() => {
        'host_id': hostId,
        'host_name': hostName,
        'succeeded': succeeded,
        'rolled_back': rolledBack,
        'error': error,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}
