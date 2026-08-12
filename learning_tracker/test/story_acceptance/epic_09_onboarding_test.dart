/// Story acceptance coverage for Epic 9 — onboarding.
@Tags(['epic_9'])
library;

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:test/test.dart';

void main() {
  group('Story 9.1 — welcome flow', tags: ['story_9_1'], () {
    test('email and password validation rules are preserved', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(validateEmail('invalid', l10n), isNotNull);
      expect(validateEmail('user@example.com', l10n), isNull);
      expect(validatePassword('12345', l10n), isNotNull);
      expect(validatePassword('123456', l10n), isNull);
    });
  });

  group('Story 9.2 — curriculum selection', tags: ['story_9_2'], () {
    test('all selectable curricula have stable storage keys', () {
      for (final curriculum in CurriculumId.values) {
        expect(curriculum.storageKey, isNotEmpty);
      }
    });
  });

  group('Story 9.3 — goal setup', tags: ['story_9_3'], skip:
      'Blocked: onboarding goal/stage persistence still constructs Drift-backed repositories; the Firestore provider seam is not available to this flow.',
      () {
    test('placeholder for the pending Firestore goal-setup seam', () {});
  });

  group('Story 9.4 — bulk prior completions', tags: ['story_9_4'], skip:
      'Blocked: BulkPriorCompletionService still writes Drift completion/import tables; no Firestore-native production flow is exposed.',
      () {
    test('placeholder for the pending Firestore bulk-import seam', () {});
  });
}
