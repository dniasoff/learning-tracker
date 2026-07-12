import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;
  const profileId = 1;
  const curriculumId = 'bavli';

  setUp(() async {
    db = inMemoryDb();
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('StudyDayConfigDao', () {
    group('upsertDayConfig', () {
      test('inserts a new row', () async {
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: 1,
          dayType: 'study',
        );
        final rows = await db.select(db.studyDayConfigs).get();
        expect(rows, hasLength(1));
        expect(rows.first.dayOfWeek, 1);
        expect(rows.first.dayType, 'study');
      });

      test('updates an existing row on conflict', () async {
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: 2,
          dayType: 'study',
        );
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: 2,
          dayType: 'rest',
        );
        final rows = await db.select(db.studyDayConfigs).get();
        expect(rows, hasLength(1));
        expect(rows.first.dayType, 'rest');
      });
    });

    group('seedDefaults / seedDefaultsForTrack', () {
      test('seedDefaults writes 7 rows all marked study', () async {
        await db.studyDayConfigDao.seedDefaults(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
        );
        final rows = await db.select(db.studyDayConfigs).get();
        expect(rows, hasLength(7));
        expect(rows.every((r) => r.dayType == 'study'), isTrue);
      });

      test(
        'seedDefaultsForTrack resolves profile+curriculum from track',
        () async {
          await db.studyDayConfigDao.seedDefaultsForTrack(trackId: trackId);
          final rows = await db.studyDayConfigDao
              .getConfigsByCurriculumAndProfile(curriculumId, profileId);
          expect(rows, hasLength(7));
        },
      );

      test('seedDefaultsForTrack throws a typed DaoInvariantError with a '
          'stable code, not a raw English message, when track not found '
          '(AUD-core-database-14, EH-5)', () async {
        expect(
          () => db.studyDayConfigDao.seedDefaultsForTrack(trackId: 9999),
          throwsA(
            isA<DaoInvariantError>().having(
              (e) => e.code,
              'code',
              DaoErrorCode.studyDayTrackNotFound,
            ),
          ),
        );
      });
    });

    group('getConfigsByCurriculumAndProfile / watch', () {
      test('returns rows ordered by dayOfWeek ascending', () async {
        await db.studyDayConfigDao.seedDefaults(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
        );
        final rows = await db.studyDayConfigDao
            .getConfigsByCurriculumAndProfile(curriculumId, profileId);
        expect(rows.map((r) => r.dayOfWeek), [1, 2, 3, 4, 5, 6, 7]);
      });

      test('watchConfigsByCurriculumAndProfile emits current rows', () async {
        await db.studyDayConfigDao.seedDefaults(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
        );
        final first = await db.studyDayConfigDao
            .watchConfigsByCurriculumAndProfile(curriculumId, profileId)
            .first;
        expect(first, hasLength(7));
      });

      test('returns empty for unknown profile/curriculum', () async {
        final rows = await db.studyDayConfigDao
            .getConfigsByCurriculumAndProfile('unknown', 999);
        expect(rows, isEmpty);
      });
    });

    group('getConfigsByTrack / watch', () {
      test('returns rows for the given track only', () async {
        await db.studyDayConfigDao.seedDefaultsForTrack(trackId: trackId);
        final rows = await db.studyDayConfigDao.getConfigsByTrack(trackId);
        expect(rows, hasLength(7));

        // empty for a different track
        expect(await db.studyDayConfigDao.getConfigsByTrack(9999), isEmpty);
      });

      test('watchConfigsByTrack emits the current rows', () async {
        await db.studyDayConfigDao.seedDefaultsForTrack(trackId: trackId);
        final first = await db.studyDayConfigDao
            .watchConfigsByTrack(trackId)
            .first;
        expect(first, hasLength(7));
      });
    });

    group('isStudyDay / isStudyDayForTrack', () {
      test('returns true by default (no config row → assume study)', () async {
        final isStudy = await db.studyDayConfigDao.isStudyDay(
          profileId: profileId,
          curriculumId: curriculumId,
          dayOfWeek: 3,
        );
        expect(isStudy, isTrue);
      });

      test('returns false when day is configured as rest', () async {
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: 6,
          dayType: 'rest',
        );
        final isStudy = await db.studyDayConfigDao.isStudyDay(
          profileId: profileId,
          curriculumId: curriculumId,
          dayOfWeek: 6,
        );
        expect(isStudy, isFalse);
      });

      test(
        'isStudyDayForTrack works the same way against the track key',
        () async {
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            dayOfWeek: 7,
            dayType: 'rest',
          );
          expect(
            await db.studyDayConfigDao.isStudyDayForTrack(
              trackId: trackId,
              dayOfWeek: 7,
            ),
            isFalse,
          );
          expect(
            await db.studyDayConfigDao.isStudyDayForTrack(
              trackId: trackId,
              dayOfWeek: 1,
            ),
            isTrue,
          );
        },
      );
    });

    group('getStudyDaysPerWeek', () {
      test('returns 7 when no configs exist (default)', () async {
        final n = await db.studyDayConfigDao.getStudyDaysPerWeek(
          profileId: profileId,
          curriculumId: curriculumId,
        );
        expect(n, 7);
      });

      test('counts the rows marked study', () async {
        for (var d = 1; d <= 5; d++) {
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            dayOfWeek: d,
            dayType: 'study',
          );
        }
        for (var d = 6; d <= 7; d++) {
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            dayOfWeek: d,
            dayType: 'rest',
          );
        }
        final n = await db.studyDayConfigDao.getStudyDaysPerWeek(
          profileId: profileId,
          curriculumId: curriculumId,
        );
        expect(n, 5);
      });

      test(
        'getStudyDaysPerWeekForTrack mirrors the profile-scoped variant',
        () async {
          await db.studyDayConfigDao.seedDefaultsForTrack(trackId: trackId);
          final n = await db.studyDayConfigDao.getStudyDaysPerWeekForTrack(
            trackId: trackId,
          );
          expect(n, 7);
        },
      );
    });

    group('countStudyDaysInInclusiveDateRangeForTrack', () {
      test('returns 0 when start is after end', () async {
        final n = await db.studyDayConfigDao
            .countStudyDaysInInclusiveDateRangeForTrack(
              trackId: trackId,
              startInclusive: DateTime.utc(2026, 5, 10),
              endInclusive: DateTime.utc(2026, 5, 5),
            );
        expect(n, 0);
      });

      test(
        'counts all 7 days inclusive when no configs (default = all study)',
        () async {
          final n = await db.studyDayConfigDao
              .countStudyDaysInInclusiveDateRangeForTrack(
                trackId: trackId,
                startInclusive: DateTime.utc(2026, 5, 4), // Mon
                endInclusive: DateTime.utc(2026, 5, 10), // Sun
              );
          expect(n, 7);
        },
      );

      test('excludes rest days from the count', () async {
        // Mark Saturday (Dart weekday 6) as rest.
        for (var d = 1; d <= 5; d++) {
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            dayOfWeek: d,
            dayType: 'study',
          );
        }
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: 6,
          dayType: 'rest',
        );
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: 7,
          dayType: 'study',
        );
        // Mon 2026-05-04 .. Sun 2026-05-10 → 7 days, 1 rest → 6 study.
        final n = await db.studyDayConfigDao
            .countStudyDaysInInclusiveDateRangeForTrack(
              trackId: trackId,
              startInclusive: DateTime.utc(2026, 5, 4),
              endInclusive: DateTime.utc(2026, 5, 10),
            );
        expect(n, 6);
      });
    });

    group('delete operations', () {
      test('deleteConfigsForTrack removes all rows for the track', () async {
        await db.studyDayConfigDao.seedDefaultsForTrack(trackId: trackId);
        final removed = await db.studyDayConfigDao.deleteConfigsForTrack(
          trackId,
        );
        expect(removed, 7);
        final rows = await db.select(db.studyDayConfigs).get();
        expect(rows, isEmpty);
      });

      test(
        'deleteConfigsByCurriculumAndProfile removes all rows for that pair',
        () async {
          await db.studyDayConfigDao.seedDefaults(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
          );
          final removed = await db.studyDayConfigDao
              .deleteConfigsByCurriculumAndProfile(curriculumId, profileId);
          expect(removed, 7);
        },
      );
    });

    group('getLatestUpdatedAt', () {
      test('returns null when no rows exist', () async {
        final t = await db.studyDayConfigDao.getLatestUpdatedAt(
          profileId: profileId,
          curriculumId: curriculumId,
        );
        expect(t, isNull);
      });

      test('returns the max updatedAt across rows', () async {
        await db.studyDayConfigDao.seedDefaults(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
        );
        final t = await db.studyDayConfigDao.getLatestUpdatedAt(
          profileId: profileId,
          curriculumId: curriculumId,
        );
        expect(t, isNotNull);
      });
    });
  });
}
