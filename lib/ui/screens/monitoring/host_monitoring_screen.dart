import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../../widgets/metric_card.dart';

class HostMonitoringScreen extends ConsumerWidget {
  final String hostId;

  const HostMonitoringScreen({super.key, required this.hostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(hostDetailProvider(hostId));
    final metricsAsync = ref.watch(hostMetricsProvider(hostId));
    final healthAsync = ref.watch(healthScoreProvider(hostId));

    return Scaffold(
      appBar: AppBar(
        title: hostAsync.when(
          data: (host) => Text('${host?.name ?? 'Host'} - Monitoring'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
      ),
      body: metricsAsync.when(
        data: (metrics) {
          if (metrics.isEmpty) {
            return const Center(child: Text('No metrics available', style: TextStyle(color: AppTheme.textSecondary)));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHealthScore(healthAsync),
              const SizedBox(height: 16),
              _buildCpuChart(),
              const SizedBox(height: 16),
              _buildMemoryChart(),
              const SizedBox(height: 16),
              _buildMetricsGrid(metrics),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading metrics: $e')),
      ),
    );
  }

  Widget _buildHealthScore(AsyncValue<int> healthAsync) {
    return healthAsync.when(
      data: (score) {
        final color = score >= 80 ? AppTheme.successGreen : score >= 50 ? AppTheme.warningOrange : AppTheme.dangerRed;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 4),
                  ),
                  child: Center(child: Text('$score', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Health Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        score >= 80 ? 'System healthy' : score >= 50 ? 'System degraded' : 'System critical',
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                ),
                // Health progress bar
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: AppTheme.bgSurface,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCpuChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CPU Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.borderDefault, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)))),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(20, (i) => FlSpot(i.toDouble(), (30 + (i * 1.5) % 40).toDouble())),
                      isCurved: true,
                      color: AppTheme.primaryBlue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Memory Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.borderDefault, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)))),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(20, (i) => FlSpot(i.toDouble(), (50 + (i * 2.3) % 35).toDouble())),
                      isCurved: true,
                      color: AppTheme.infoCyan,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppTheme.infoCyan.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(List<dynamic> metrics) {
    final cpuUsage = metrics.where((m) => m.collectorId == 'cpu_usage').firstOrNull;
    final memUsage = metrics.where((m) => m.collectorId == 'memory_usage_pct').firstOrNull;
    final diskUsage = metrics.where((m) => m.collectorId == 'disk_usage_pct').firstOrNull;
    final load1m = metrics.where((m) => m.collectorId == 'cpu_load_1m').firstOrNull;
    final procRunning = metrics.where((m) => m.collectorId == 'proc_running').firstOrNull;
    final svcFailed = metrics.where((m) => m.collectorId == 'svc_failed').firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Current Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricCard(label: 'CPU', value: '${cpuUsage?.value ?? "--"}%', icon: Icons.memory, color: AppTheme.primaryBlue)),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'Memory', value: '${memUsage?.value ?? "--"}%', icon: Icons.storage, color: AppTheme.infoCyan)),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'Disk', value: '${diskUsage?.value ?? "--"}%', icon: Icons.disc_full, color: AppTheme.warningOrange)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricCard(label: 'Load', value: load1m?.value ?? '--', icon: Icons.trending_up, color: AppTheme.primaryBlue)),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'Processes', value: procRunning?.value ?? '--', icon: Icons.apps, color: AppTheme.successGreen)),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'Failed Svc', value: svcFailed?.value ?? '--', icon: Icons.warning, color: svcFailed != null && svcFailed.numericValue != null && svcFailed.numericValue! > 0 ? AppTheme.dangerRed : AppTheme.successGreen)),
          ],
        ),
      ],
    );
  }
}
