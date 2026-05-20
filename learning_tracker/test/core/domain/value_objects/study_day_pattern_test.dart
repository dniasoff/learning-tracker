import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/study_day_pattern.dart';

void main() {
  group('DayKind', () {
    group('storageKey', () {
      test('study → "study"', () {
        expect(DayKind.study.storageKey, 'study');
      });

      test('review → "review"', () {
        expect(DayKind.review.storageKey, 'review');
      });
    });

    group('fromStorageKey', () {
      test('parses "study"', () {
        expect(DayKind.fromStorageKey('study'), DayKind.study);
      });

      test('parses "review"', () {
        expect(DayKind.fromStorageKey('review'), DayKind.review);
      });

      test('throws for unknown key', () {
        expect(() => DayKind.fromStorageKey('unknown'), throwsArgumentError);
      });
    });
  });

  group('StudyDayPattern', () {
    // -------------------------------------------------------------------------
    // Construction + validation
    // -------------------------------------------------------------------------

    group('construction', () {
      test('constructs with valid map', () {
        final p = StudyDayPattern({1: DayKind.study, 2: DayKind.review});
        expect(p.entries.length, 2);
      });

      test('throws for weekday 0', () {
        expect(
          () => StudyDayPattern({0: DayKind.study, 1: DayKind.study}),
          throwsArgumentError,
        );
      });

      test('throws for weekday 8', () {
        expect(
          () => StudyDayPattern({1: DayKind.study, 8: DayKind.study}),
          throwsArgumentError,
        );
      });

      test('throws when no study day is present', () {
        expect(
          () => StudyDayPattern({1: DayKind.review, 2: DayKind.review}),
          throwsArgumentError,
        );
      });

      test('allows a map with only study days', () {
        final p = StudyDayPattern({for (var i = 1; i <= 7; i++) i: DayKind.study});
        expect(p.studyDaysPerWeek, 7);
      });
    });

    // -------------------------------------------------------------------------
    // Factory constructors
    // -------------------------------------------------------------------------

    group('allStudy', () {
      test('creates 7-day study pattern', () {
        final p = StudyDayPattern.allStudy();
        expect(p.studyDaysPerWeek, 7);
        for (var i = 1; i <= 7; i++) {
          expect(p.dayKindFor(i), DayKind.study);
        }
      });
    });

    group('weekdaysStudy', () {
      test('Mon-Fri are study days', () {
        final p = StudyDayPattern.weekdaysStudy();
        for (var i = 1; i <= 5; i++) {
          expect(p.isStudyDay(i), isTrue);
        }
      });

      test('Sat-Sun are review days', () {
        final p = StudyDayPattern.weekdaysStudy();
        expect(p.isReviewDay(6), isTrue);
        expect(p.isReviewDay(7), isTrue);
      });

      test('studyDaysPerWeek is 5', () {
        expect(StudyDayPattern.weekdaysStudy().studyDaysPerWeek, 5);
      });
    });

    // -------------------------------------------------------------------------
    // dayKindFor
    // -------------------------------------------------------------------------

    group('dayKindFor', () {
      late StudyDayPattern pattern;

      setUp(() {
        pattern = StudyDayPattern({
          1: DayKind.study,
          2: DayKind.review,
        });
      });

      test('returns mapped value', () {
        expect(pattern.dayKindFor(1), DayKind.study);
        expect(pattern.dayKindFor(2), DayKind.review);
      });

      test('defaults to study for unmapped weekday', () {
        // 3 is not in the map
        expect(pattern.dayKindFor(3), DayKind.study);
      });
    });

    // -------------------------------------------------------------------------
    // Equality
    // -------------------------------------------------------------------------

    group('equality', () {
      test('equal patterns with same entries', () {
        final a = StudyDayPattern({1: DayKind.study, 2: DayKind.review});
        final b = StudyDayPattern({1: DayKind.study, 2: DayKind.review});
        expect(a, equals(b));
      });

      test('not equal for different entries', () {
        final a = StudyDayPattern({1: DayKind.study, 2: DayKind.study});
        final b = StudyDayPattern({1: DayKind.study, 2: DayKind.review});
        expect(a, isNot(equals(b)));
      });

      test('not equal for different key sets', () {
        final a = StudyDayPattern({1: DayKind.study});
        final b = StudyDayPattern({1: DayKind.study, 2: DayKind.study});
        expect(a, isNot(equals(b)));
      });

      test('hashCode consistent with equality', () {
        final a = StudyDayPattern.allStudy();
        final b = StudyDayPattern.allStudy();
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------

    test('toString includes day numbers', () {
      final p = StudyDayPattern({1: DayKind.study, 2: DayKind.review});
      final str = p.toString();
      expect(str, contains('1'));
      expect(str, contains('2'));
    });
  });
}
