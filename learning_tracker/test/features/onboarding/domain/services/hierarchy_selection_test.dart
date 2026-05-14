// Tests for HierarchySelection — covers == and hashCode (lines 218-228).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';

void main() {
  group('HierarchySelection.== and hashCode', () {
    test('two identical instances are equal', () {
      const a = HierarchySelection(level1: 'Zeraim', level2: 'Berakhot');
      const b = HierarchySelection(level1: 'Zeraim', level2: 'Berakhot');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances with different level1 are not equal', () {
      const a = HierarchySelection(level1: 'Zeraim');
      const b = HierarchySelection(level1: 'Moed');
      expect(a, isNot(equals(b)));
    });

    test('instances with different level2 are not equal', () {
      const a = HierarchySelection(level1: 'Zeraim', level2: 'Berakhot');
      const b = HierarchySelection(level1: 'Zeraim', level2: 'Peah');
      expect(a, isNot(equals(b)));
    });

    test('instance is equal to itself (identical)', () {
      const a = HierarchySelection(level1: 'Zeraim');
      expect(a == a, isTrue);
    });

    test('instance is not equal to a non-HierarchySelection object', () {
      const a = HierarchySelection(level1: 'Zeraim');
      // ignore: unrelated_type_equality_checks
      expect(a == 'Zeraim', isFalse);
    });

    test('all null fields are equal', () {
      const a = HierarchySelection();
      const b = HierarchySelection();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('level3 and level4 differences are reflected in equality', () {
      const a = HierarchySelection(level1: 'L1', level2: 'L2', level3: '1');
      const b = HierarchySelection(level1: 'L1', level2: 'L2', level3: '2');
      expect(a, isNot(equals(b)));
    });
  });
}
