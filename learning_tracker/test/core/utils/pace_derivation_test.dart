import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/pace_derivation.dart';

void main() {
  group('derivePaceFromDeadline', () {
    test('zero scope returns fallback 1/week', () {
      final result = derivePaceFromDeadline(
        totalScopeItems: 0,
        studyDaysInWindow: 10,
        studyDaysPerWeek: 5,
      );
      expect(result.paceValue, 1);
      expect(result.pacePeriod, 'per_week');
    });

    test('zero studyDaysInWindow returns fallback 1/week', () {
      final result = derivePaceFromDeadline(
        totalScopeItems: 100,
        studyDaysInWindow: 0,
        studyDaysPerWeek: 5,
      );
      expect(result.paceValue, 1);
      expect(result.pacePeriod, 'per_week');
    });

    test('basic math — 100 items / 20 study days × 5 days/week = 25/week', () {
      // perStudyDay = ceil(100/20) = 5; perWeek = 5 * 5 = 25
      final result = derivePaceFromDeadline(
        totalScopeItems: 100,
        studyDaysInWindow: 20,
        studyDaysPerWeek: 5,
      );
      expect(result.paceValue, 25);
      expect(result.pacePeriod, 'per_week');
    });

    test('ceil — 101 items / 20 study days = ceil(5.05)=6 per study-day', () {
      final result = derivePaceFromDeadline(
        totalScopeItems: 101,
        studyDaysInWindow: 20,
        studyDaysPerWeek: 5,
      );
      // perStudyDay = ceil(101/20) = 6; perWeek = 6 * 5 = 30
      expect(result.paceValue, 30);
      expect(result.pacePeriod, 'per_week');
    });

    test('studyDaysPerWeek clamped to [1, 7]', () {
      // studyDaysPerWeek of 0 should clamp to 1
      final lowClamp = derivePaceFromDeadline(
        totalScopeItems: 50,
        studyDaysInWindow: 10,
        studyDaysPerWeek: 0,
      );
      // perStudyDay = ceil(50/10) = 5; perWeek = 5 * 1 = 5
      expect(lowClamp.paceValue, 5);

      // studyDaysPerWeek of 10 should clamp to 7
      final highClamp = derivePaceFromDeadline(
        totalScopeItems: 50,
        studyDaysInWindow: 10,
        studyDaysPerWeek: 10,
      );
      // perStudyDay = ceil(50/10) = 5; perWeek = 5 * 7 = 35
      expect(highClamp.paceValue, 35);
    });

    test('Mishnayot-like 4192 items over ~918 study days, 7-day week', () {
      // perStudyDay = ceil(4192/918) = 5; perWeek = 5 * 7 = 35
      final result = derivePaceFromDeadline(
        totalScopeItems: 4192,
        studyDaysInWindow: 918,
        studyDaysPerWeek: 7,
      );
      expect(result.paceValue, 35);
      expect(result.pacePeriod, 'per_week');
    });

    test('result is always at least 1/week even for tiny scope', () {
      final result = derivePaceFromDeadline(
        totalScopeItems: 1,
        studyDaysInWindow: 1000,
        studyDaysPerWeek: 7,
      );
      // perStudyDay = ceil(1/1000) = 1; perWeek = 1 * 7 = 7
      expect(result.paceValue, greaterThanOrEqualTo(1));
    });
  });
}
