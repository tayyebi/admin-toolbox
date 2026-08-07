import 'package:admin_toolbox/modules/alerting/alert_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlertEngine.testCondition', () {
    test('supports symbolic operators', () {
      expect(AlertEngine.testCondition('>', 95, 90), isTrue);
      expect(AlertEngine.testCondition('>', 85, 90), isFalse);
      expect(AlertEngine.testCondition('<', 5, 10), isTrue);
      expect(AlertEngine.testCondition('<', 15, 10), isFalse);
      expect(AlertEngine.testCondition('>=', 90, 90), isTrue);
      expect(AlertEngine.testCondition('<=', 90, 90), isTrue);
      expect(AlertEngine.testCondition('==', 90, 90), isTrue);
      expect(AlertEngine.testCondition('!=', 91, 90), isTrue);
    });

    test('supports the word forms a rule editor may store', () {
      expect(AlertEngine.testCondition('above', 95, 90), isTrue);
      expect(AlertEngine.testCondition('below', 5, 10), isTrue);
      expect(AlertEngine.testCondition('gt', 95, 90), isTrue);
      expect(AlertEngine.testCondition('lte', 90, 90), isTrue);
      expect(AlertEngine.testCondition('equals', 90, 90), isTrue);
    });

    test('tolerates surrounding whitespace', () {
      expect(AlertEngine.testCondition('  >  ', 95, 90), isTrue);
    });

    test('an unknown operator never fires', () {
      // Failing closed matters: an unparseable rule that fired on every cycle
      // would bury the real alerts.
      expect(AlertEngine.testCondition('~=', 95, 90), isFalse);
      expect(AlertEngine.testCondition('', 95, 90), isFalse);
    });

    test('boundary values are not treated as breaches by >', () {
      expect(AlertEngine.testCondition('>', 90, 90), isFalse);
    });
  });
}
