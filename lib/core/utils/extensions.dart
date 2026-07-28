extension StringExtensions on String {
  bool get isNullOrEmpty => isEmpty;

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String get iso8601 => toIso8601String();
}

String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  int i = 0;
  while (bytes >= 1024) {
    bytes = bytes ~/ 1024;
    i++;
  }
  return '${(bytes / 1.power(i * 3)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

extension PowerExtension on num {
  num power(int exponent) {
    num result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= this;
    }
    return result;
  }
}

String formatPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}

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
