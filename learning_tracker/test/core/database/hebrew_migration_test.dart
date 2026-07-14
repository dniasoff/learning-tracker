// AUD-t-cross-25: this file used to be titled "Schema migration v23→v24:
// Hebrew stage names" and drove a hand-copied `_runHebrewMigration` helper
// that re-typed the English->Hebrew UPDATE statements locally and executed
// them directly against the test DB. That helper was entirely disconnected
// from production code: `user_database.dart`'s `onUpgrade` has no
// `if (from < 24)` step (the earliest guard is `if (from < 25)`), so nothing
// in `UserDatabase.migration` ever ran, or could have run, that SQL. Deleting
// a real migration step in production would not have failed this file.
//
// Today, English->Hebrew stage-name resolution is not a DB migration at all:
// new rows are written with the Hebrew sentinel value directly
// (`kLimudStageName` etc., AUD-onboarding-14; see
// `lib/core/constants/curriculum_defaults.dart`), and legacy English-keyed
// rows are converted to the correct *display* string at render time by
// `DomainTermLabels.resolveStoredStageName`
// (`lib/core/labels/domain_term_labels.dart`), which reads
// `HebrewTerms.stageNameMap` (`lib/core/constants/hebrew_terms.dart`). The
// stored DB value is never rewritten by that path either.
//
// This file now tests that real, current-schema behavior instead of a
// migration version that doesn't exist:
//   - Group 1 confirms `UserDatabase` performs no Hebrew conversion of its
//     own — whatever `stage_name` string is written is the string read back.
//   - Group 2 feeds DB-round-tripped legacy English stage names through the
//     real `DomainTermLabels.resolveStoredStageName` production resolver and
//     asserts the resulting display string against literals that are
//     independent of `HebrewTerms.stageNameMap` — so breaking that map (e.g.
//     a wrong or deleted entry) fails these tests. (Verified by temporarily
//     corrupting `HebrewTerms.stageNameMap['Learn']` and observing group 2's
//     first two tests go red; see the fix commit message for the captured
//     failure.)
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

import '../../helpers/test_database.dart';

void main() {
  group('Stage definitions: stage_name persists verbatim (current schema)', () {
    late UserDatabase db;
    late int bavliTrackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      bavliTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'a legacy English stage name is stored and read back unmodified',
      () async {
        // No `if (from < 24)` (or any) step in onUpgrade rewrites stage_name
        // -- the DB layer performs no Hebrew conversion of its own.
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: HebrewTerms.stageLearnEn, // 'Learn'
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'bavli',
        );
        expect(stages, hasLength(1));
        expect(stages.first.stageName, 'Learn');
      },
    );

    test('a Hebrew stage name is stored and read back unmodified', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: kLimudStageName, // 'לימוד' -- the real write-path value
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum('bavli');
      expect(stages.first.stageName, 'לימוד');
    });
  });

  group(
    'Stage name display resolution: DomainTermLabels.resolveStoredStageName '
    '(the real production path -- not a DB migration)',
    () {
      late UserDatabase db;
      late int bavliTrackId;
      late int mishnayosTrackId;
      late int mbTrackId;

      setUp(() async {
        db = createTestDatabase();
        await seedProfile(db);
        bavliTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        mishnayosTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        mbTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishna_berurah',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
      });

      tearDown(() async {
        await db.close();
      });

      /// Inserts [stageName] as [stageOrder] for [curriculumId]/[trackId],
      /// reads it back from the real DB, and returns the stored value -- so
      /// assertions below resolve display strings from an actual DB round
      /// trip, not a hand-typed literal standing in for one.
      Future<String> storeAndReadBack({
        required String curriculumId,
        required int trackId,
        required String stageName,
        required int stageOrder,
      }) async {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: stageOrder,
            stageName: stageName,
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );
        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          curriculumId,
        );
        return stages.firstWhere((s) => s.stageOrder == stageOrder).stageName;
      }

      test(
        'legacy "Learn" resolves to "לימוד" display with Hebrew Terms on',
        () async {
          final stored = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: 'Learn',
          );

          const terms = DomainTermLabels(true); // Hebrew Terms ON
          expect(terms.resolveStoredStageName(stored), 'לימוד');
        },
      );

      test(
        'legacy "Learn" resolves to "Limud" display with Hebrew Terms off',
        () async {
          final stored = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: 'Learn',
          );

          const terms = DomainTermLabels(false); // Hebrew Terms OFF
          expect(terms.resolveStoredStageName(stored), 'Limud');
        },
      );

      test(
        'legacy "Chazara 1" / "Chazara 2" resolve to Hebrew numerals',
        () async {
          final chazara1 = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: 'Chazara 1',
          );
          final chazara2 = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 2,
            stageName: 'Chazara 2',
          );

          const terms = DomainTermLabels(true);
          expect(terms.resolveStoredStageName(chazara1), 'חזרה א׳');
          expect(terms.resolveStoredStageName(chazara2), 'חזרה ב׳');
        },
      );

      test('legacy "Review" resolves to Hebrew "חזרה"', () async {
        final stored = await storeAndReadBack(
          curriculumId: 'mishna_berurah',
          trackId: mbTrackId,
          stageOrder: 1,
          stageName: 'Review',
        );

        const terms = DomainTermLabels(true);
        expect(terms.resolveStoredStageName(stored), 'חזרה');
      });

      test('legacy Oraysa program labels resolve to Hebrew', () async {
        final nextDay = await storeAndReadBack(
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'Next-Day Review',
        );
        final weekly = await storeAndReadBack(
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 2,
          stageName: 'Weekly Review',
        );
        final rolling = await storeAndReadBack(
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 3,
          stageName: 'Rolling Back-20',
        );

        const terms = DomainTermLabels(true);
        expect(terms.resolveStoredStageName(nextDay), 'חזרה יומית');
        expect(terms.resolveStoredStageName(weekly), 'חזרה שבועית');
        expect(terms.resolveStoredStageName(rolling), 'חזרה מחזורית');
      });

      test(
        'user-customized stage names are returned unchanged by the resolver',
        () async {
          final custom1 = await storeAndReadBack(
            curriculumId: 'mishnayos',
            trackId: mishnayosTrackId,
            stageOrder: 1,
            stageName: 'My Morning Study',
          );
          final custom2 = await storeAndReadBack(
            curriculumId: 'mishnayos',
            trackId: mishnayosTrackId,
            stageOrder: 2,
            stageName: 'Evening Review Session',
          );

          const termsHe = DomainTermLabels(true);
          const termsEn = DomainTermLabels(false);
          expect(termsHe.resolveStoredStageName(custom1), 'My Morning Study');
          expect(
            termsHe.resolveStoredStageName(custom2),
            'Evening Review Session',
          );
          expect(termsEn.resolveStoredStageName(custom1), 'My Morning Study');
          expect(
            termsEn.resolveStoredStageName(custom2),
            'Evening Review Session',
          );
        },
      );

      test(
        'mixed legacy defaults and custom names: only defaults resolve',
        () async {
          final learnStage = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: 'Learn',
          );
          final customStage = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 2,
            stageName: 'Quick Review',
          );
          final chazara2Stage = await storeAndReadBack(
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 3,
            stageName: 'Chazara 2',
          );

          const terms = DomainTermLabels(true);
          expect(terms.resolveStoredStageName(learnStage), 'לימוד'); // resolved
          expect(
            terms.resolveStoredStageName(customStage),
            'Quick Review',
          ); // untouched
          expect(
            terms.resolveStoredStageName(chazara2Stage),
            'חזרה ב׳',
          ); // resolved
        },
      );
    },
  );
}
