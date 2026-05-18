import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
  group('HebrewTerms', () {
    group('getDefaultStageName', () {
      test('index 0 returns לימוד', () {
        expect(HebrewTerms.getDefaultStageName(0), 'לימוד');
      });

      test('negative index returns לימוד', () {
        expect(HebrewTerms.getDefaultStageName(-1), 'לימוד');
      });

      test('index 1 returns חזרה א׳', () {
        expect(HebrewTerms.getDefaultStageName(1), 'חזרה א׳');
      });

      test('index 2 returns חזרה ב׳', () {
        expect(HebrewTerms.getDefaultStageName(2), 'חזרה ב׳');
      });

      test('index 3 returns חזרה ג׳', () {
        expect(HebrewTerms.getDefaultStageName(3), 'חזרה ג׳');
      });
    });

    group('getChazaraStageName', () {
      test('round 1 returns חזרה א׳', () {
        expect(HebrewTerms.getChazaraStageName(1), 'חזרה א׳');
      });

      test('round 2 returns חזרה ב׳', () {
        expect(HebrewTerms.getChazaraStageName(2), 'חזרה ב׳');
      });

      test('round 5 returns חזרה ה׳', () {
        expect(HebrewTerms.getChazaraStageName(5), 'חזרה ה׳');
      });

      test('round beyond 5 falls back to numeric', () {
        expect(HebrewTerms.getChazaraStageName(6), 'חזרה 6');
      });
    });

    group('toHebrew', () {
      test('converts known English defaults', () {
        expect(HebrewTerms.toHebrew('Learn'), 'לימוד');
        expect(HebrewTerms.toHebrew('Chazara 1'), 'חזרה א׳');
        expect(HebrewTerms.toHebrew('Chazara 2'), 'חזרה ב׳');
        expect(HebrewTerms.toHebrew('Chazara 3'), 'חזרה ג׳');
        expect(HebrewTerms.toHebrew('Review'), 'חזרה');
        expect(HebrewTerms.toHebrew('Review 1'), 'חזרה א׳');
        expect(HebrewTerms.toHebrew('Review 2'), 'חזרה ב׳');
        expect(HebrewTerms.toHebrew('Next-Day Review'), 'חזרה יומית');
        expect(HebrewTerms.toHebrew('Weekly Review'), 'חזרה שבועית');
        expect(HebrewTerms.toHebrew('Rolling Back-20'), 'חזרה מחזורית');
      });

      test('returns null for user-customized names', () {
        expect(HebrewTerms.toHebrew('My Custom Stage'), isNull);
        expect(HebrewTerms.toHebrew('Morning Study'), isNull);
        expect(HebrewTerms.toHebrew(''), isNull);
      });

      test('returns null for already-Hebrew names (idempotent)', () {
        expect(HebrewTerms.toHebrew('לימוד'), isNull);
        expect(HebrewTerms.toHebrew('חזרה א׳'), isNull);
      });
    });

    group('getCurriculumDisplayName', () {
      test('returns Hebrew for every CurriculumId', () {
        for (final id in CurriculumId.values) {
          final name = HebrewTerms.getCurriculumDisplayName(id);
          expect(
            name,
            isNotEmpty,
            reason: '${id.name} should have Hebrew name',
          );
          expect(name, id.displayNameHe);
        }
      });

      test('specific values match expected Hebrew', () {
        expect(
          HebrewTerms.getCurriculumDisplayName(CurriculumId.mishnayos),
          'משניות',
        );
        expect(
          HebrewTerms.getCurriculumDisplayName(CurriculumId.bavli),
          'תלמוד בבלי',
        );
        expect(
          HebrewTerms.getCurriculumDisplayName(CurriculumId.chumash),
          'חומש',
        );
      });
    });

    group('getCurriculumDisplayName', () {
      test('returns displayNameHe for every CurriculumId', () {
        for (final id in CurriculumId.values) {
          expect(
            HebrewTerms.getCurriculumDisplayName(id),
            id.displayNameHe,
            reason: '${id.storageKey} should return displayNameHe',
          );
        }
      });
    });

    group('stageNameMap', () {
      test('covers all knownEnglishDefaults', () {
        for (final name in HebrewTerms.knownEnglishDefaults) {
          expect(
            HebrewTerms.stageNameMap.containsKey(name),
            isTrue,
            reason: '$name should be in stageNameMap',
          );
        }
      });
    });
  });
}
