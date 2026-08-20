import '../../../core/utils/logger.dart';
import '../../../data/models/metric.dart';
import '../../../data/transport/transport.dart';

/// One reading taken from a host.
///
/// [command] and [parse] are kept apart from [collect] on purpose: parsing is
/// pure, so it can be tested against captured output with no connection, and
/// the commands can later be batched into a single round trip without any
/// parser noticing.
abstract class MetricCollector {
  const MetricCollector({
    required this.id,
    required this.name,
    required this.description,
    this.supportedOs = const {'linux', 'bsd'},
    this.timeout = const Duration(seconds: 10),
    this.cacheDuration = const Duration(seconds: 30),
    this.refreshInterval = const Duration(seconds: 60),
  });

  final String id;
  final String name;
  final String description;
  final Set<String> supportedOs;
  final Duration timeout;
  final Duration cacheDuration;
  final Duration refreshInterval;

  String get command;

  List<Metric> parse(String rawOutput, String hostId);

  bool supports(String os) => supportedOs.contains(os.toLowerCase());

  Future<List<Metric>> collect(TransportSession transport, String hostId) async {
    try {
      final result = await transport.execute(command, timeout: timeout);
      if (result.isSuccess) return parse(result.stdout, hostId);

      logWarning('Collector $id failed with exit code ${result.exitCode}: ${result.stderr}');
      return [];
    } catch (e) {
      logError('Collector $id error', e);
      return [];
    }
  }
}
