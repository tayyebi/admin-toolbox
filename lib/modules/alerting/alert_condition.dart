import '../../core/utils/logger.dart';

/// The operators an alert rule can express.
///
/// Exposed rather than private because the rule editor previews a condition
/// live, and the tests exercise the operator table directly.
bool evaluateAlertCondition(String condition, double value, double threshold) {
  switch (condition.trim()) {
    case '>':
    case 'gt':
    case 'above':
      return value > threshold;
    case '>=':
    case 'gte':
      return value >= threshold;
    case '<':
    case 'lt':
    case 'below':
      return value < threshold;
    case '<=':
    case 'lte':
      return value <= threshold;
    case '==':
    case 'eq':
    case 'equals':
      return value == threshold;
    case '!=':
    case 'ne':
      return value != threshold;
    default:
      logWarning('Unknown alert condition "$condition"; treating as no-op');
      return false;
  }
}
