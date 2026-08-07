import 'dart:math' as math;

extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}…';
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);

    if (diff.isNegative) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String get iso8601 => toIso8601String();
}

/// Formats a byte count in binary units.
///
/// The previous implementation divided [bytes] by 1024 with integer division
/// inside the loop *and* then divided by `1.power(i * 3)`, which is always 1.
/// Both bugs pushed the same way: 1536 came out as "1.0 KB" instead of
/// "1.5 KB", and every non-exact value lost its fraction. The old tests only
/// exercised exact powers of 1024, so they passed.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';

  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB'];

  final exponent = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    suffixes.length - 1,
  );

  final value = bytes / math.pow(1024, exponent);

  // Whole bytes never need a decimal point.
  return exponent == 0
      ? '$bytes B'
      : '${value.toStringAsFixed(decimals)} ${suffixes[exponent]}';
}

String formatPercent(double value, {int decimals = 1}) =>
    '${value.toStringAsFixed(decimals)}%';

String formatDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}m');

  return parts.isEmpty ? '<1m' : parts.join(' ');
}
