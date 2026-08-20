import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Maps the app's vocabulary — severities, statuses, health scores — onto the
/// palette, so a screen never picks a colour by meaning itself.
extension SemanticColors on AppColors {

  /// Colour for an alert or incident severity label.
  Color severity(String value) {
    switch (value.toLowerCase()) {
      case 'critical':
        return danger;
      case 'warning':
      case 'high':
      case 'medium':
        return warning;
      case 'info':
      case 'low':
        return info;
      case 'success':
      case 'ok':
        return success;
      default:
        return textMuted;
    }
  }

  /// Colour for a host or service status label.
  Color status(String value) {
    switch (value.toLowerCase()) {
      case 'online':
      case 'active':
      case 'running':
      case 'healthy':
      case 'resolved':
        return success;
      case 'offline':
      case 'stopped':
      case 'critical':
      case 'failed':
        return danger;
      case 'warning':
      case 'degraded':
        return warning;
      case 'pending':
      case 'unknown':
      case 'paused':
        return textMuted;
      default:
        return info;
    }
  }

  /// Colour for a 0-100 health score.
  Color health(int score) {
    if (score >= 80) return success;
    if (score >= 50) return warning;
    return danger;
  }
}
