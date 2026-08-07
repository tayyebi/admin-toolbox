import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/metric.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/metric_card.dart';

class HostMonitoringScreen extends ConsumerWidget {
  const HostMonitoringScreen({super.key, required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(hostDetailProvider(hostId)).valueOrNull;
    final metricsAsync = ref.watch(hostMetricsProvider(hostId));

    return Scaffold(
      appBar: AppBar(title: Text(host?.name ?? 'Monitoring')),
      body: metricsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(hostMetricsProvider(hostId)),
        ),
        data: (metrics) {
          if (metrics.isEmpty) {
            return const EmptyState(
              icon: Icons.query_stats,
              title: 'No metrics yet',
              message: 'Start collection from the Monitoring tab, or check that '
                  'this host has a credential attached.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(hostMetricsProvider(hostId));
              ref.invalidate(healthScoreProvider(hostId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _HealthCard(hostId: hostId),
                const SizedBox(height: 8),
                _MetricChart(
                  hostId: hostId,
                  collectorId: 'cpu_usage',
                  title: 'CPU usage',
                  unit: '%',
                  color: context.scheme.primary,
                ),
                const SizedBox(height: 8),
                _MetricChart(
                  hostId: hostId,
                  collectorId: 'memory_usage_pct',
                  title: 'Memory usage',
                  unit: '%',
                  color: context.colors.info,
                ),
                const SizedBox(height: 8),
                _MetricChart(
                  hostId: hostId,
                  collectorId: 'disk_usage_pct',
                  title: 'Disk usage',
                  unit: '%',
                  color: context.colors.warning,
                ),
                const SizedBox(height: 16),
                _MetricsGrid(metrics: metrics),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HealthCard extends ConsumerWidget {
  const _HealthCard({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthScoreProvider(hostId));

    return health.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (score) {
        final color = context.colors.health(score);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Health score', style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      score >= 80
                          ? 'Everything looks healthy'
                          : score >= 50
                              ? 'Some subsystems are under pressure'
                              : 'Needs attention',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                Text('$score', style: AppTypography.monoMetric(color)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Plots the recorded series for one metric.
///
/// The previous version generated its data with `List.generate`, so both
/// charts showed a plausible-looking curve that had nothing to do with the
/// server. A chart that invents its own data is worse than no chart.
class _MetricChart extends ConsumerWidget {
  const _MetricChart({
    required this.hostId,
    required this.collectorId,
    required this.title,
    required this.color,
    this.unit = '',
  });

  final String hostId;
  final String collectorId;
  final String title;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync =
        ref.watch(metricSeriesProvider((hostId: hostId, collectorId: collectorId)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.titleMedium)),
                seriesAsync.maybeWhen(
                  orElse: () => const SizedBox.shrink(),
                  data: (series) {
                    final latest = _numericPoints(series.metrics);
                    if (latest.isEmpty) return const SizedBox.shrink();
                    return Text(
                      '${latest.last.y.toStringAsFixed(1)}$unit',
                      style: AppTypography.monoStyle(
                        size: 15,
                        weight: FontWeight.w500,
                        color: color,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: seriesAsync.when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(error: error, compact: true),
                data: (series) {
                  final spots = _numericPoints(series.metrics);

                  // One point cannot be drawn as a line, and pretending
                  // otherwise looks like a flat trend rather than "not enough
                  // data yet".
                  if (spots.length < 2) {
                    return Center(
                      child: Text(
                        'Not enough history yet — at least two collections are '
                        'needed to draw a trend.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: _upperBound(spots),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: context.colors.border, strokeWidth: 0.5),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, _) => Text(
                              '${value.toInt()}$unit',
                              style: AppTypography.monoStyle(
                                size: 9,
                                color: context.colors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touched) => touched
                              .map(
                                (spot) => LineTooltipItem(
                                  '${spot.y.toStringAsFixed(1)}$unit',
                                  AppTypography.monoStyle(
                                    size: 11,
                                    color: context.scheme.onSurface,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<FlSpot> _numericPoints(List<Metric> metrics) {
    final spots = <FlSpot>[];
    for (var i = 0; i < metrics.length; i++) {
      final value = metrics[i].numericValue;
      if (value != null) spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  /// Percentages get a fixed 100 ceiling; anything else scales with headroom.
  double _upperBound(List<FlSpot> spots) {
    if (unit == '%') return 100;
    final max = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return max <= 0 ? 1 : max * 1.2;
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<Metric> metrics;

  Metric? _find(String collectorId) {
    for (final metric in metrics) {
      if (metric.collectorId == collectorId) return metric;
    }
    return null;
  }

  String _value(String collectorId, {bool asBytes = false}) {
    final metric = _find(collectorId);
    if (metric == null) return '—';
    if (asBytes) {
      final bytes = int.tryParse(metric.value);
      if (bytes != null) return formatBytes(bytes);
    }
    return metric.value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failed = _find('svc_failed');
    final failedCount = failed?.numericValue ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Latest readings', style: context.text.titleMedium),
        ),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Uptime',
                value: _value('sys_uptime'),
                icon: Icons.schedule,
                color: context.scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'Processes',
                value: _value('proc_running'),
                icon: Icons.apps,
                color: colors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'Zombies',
                value: _value('proc_zombies'),
                icon: Icons.bug_report_outlined,
                color: colors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Memory total',
                value: _value('memory_total', asBytes: true),
                icon: Icons.storage,
                color: colors.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'Disk free',
                value: _value('disk_free', asBytes: true),
                icon: Icons.disc_full,
                color: colors.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'Failed units',
                value: _value('svc_failed'),
                icon: Icons.error_outline,
                color: failedCount > 0 ? colors.danger : colors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
