import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const Spacer(),
                // Monospace so a column of readouts stays aligned as digits
                // change.
                Text(value, style: AppTypography.monoStyle(size: 17, weight: FontWeight.w500, color: color)),
                if (unit != null) ...[
                  const SizedBox(width: 2),
                  Text(unit!, style: AppTypography.monoSmall(color)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
