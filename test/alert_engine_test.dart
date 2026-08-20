import 'package:admin_toolbox/modules/alerting/alert_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluateAlertCondition', () {
    test('supports symbolic operators', () {
      expect(evaluateAlertCondition('>', 95, 90), isTrue);
      expect(evaluateAlertCondition('>', 85, 90), isFalse);
      expect(evaluateAlertCondition('<', 5, 10), isTrue);
      expect(evaluateAlertCondition('<', 15, 10), isFalse);
      expect(evaluateAlertCondition('>=', 90, 90), isTrue);
      expect(evaluateAlertCondition('<=', 90, 90), isTrue);
      expect(evaluateAlertCondition('==', 90, 90), isTrue);
      expect(evaluateAlertCondition('!=', 91, 90), isTrue);
    });

    test('supports the word forms a rule editor may store', () {
      expect(evaluateAlertCondition('above', 95, 90), isTrue);
      expect(evaluateAlertCondition('below', 5, 10), isTrue);
      expect(evaluateAlertCondition('gt', 95, 90), isTrue);
      expect(evaluateAlertCondition('lte', 90, 90), isTrue);
      expect(evaluateAlertCondition('equals', 90, 90), isTrue);
    });

    test('tolerates surrounding whitespace', () {
      expect(evaluateAlertCondition('  >  ', 95, 90), isTrue);
    });

    test('an unknown operator never fires', () {
      // Failing closed matters: an unparseable rule that fired on every cycle
      // would bury the real alerts.
      expect(evaluateAlertCondition('~=', 95, 90), isFalse);
      expect(evaluateAlertCondition('', 95, 90), isFalse);
    });

    test('boundary values are not treated as breaches by >', () {
      expect(evaluateAlertCondition('>', 90, 90), isFalse);
    });
  });
}
