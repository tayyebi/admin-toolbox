import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// How loudly a severity should announce itself.
Importance importanceFor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return Importance.max;
    case 'warning':
    case 'high':
      return Importance.high;
    default:
      return Importance.defaultImportance;
  }
}

Priority priorityFor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return Priority.max;
    case 'warning':
    case 'high':
      return Priority.high;
    default:
      return Priority.defaultPriority;
  }
}
