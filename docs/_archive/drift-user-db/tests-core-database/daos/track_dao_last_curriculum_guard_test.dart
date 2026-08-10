/// Regression tests for TRK-HUB-04 — last-curriculum guard on hub/detail
/// delete dialogs.
///
/// The defect: `TrackManagementHubScreen._showDeleteDialog` and
/// `TrackDetailScreen._showDeleteDialog` both call `dao.deleteTrackAndData()`
/// (or `dao.purgeHistory()`) directly, without checking whether the track
/// being deleted is the profile's *last* active curriculum. This leaves the
/// profile with zero active curricula after the delete, which dead-ends the
/// dashboard.
///
/// These tests verify the invariant from the DAO side (the source of truth):
///   • Soft-deleting the only active track → active curricula count = 0 (BUG)
///   • Wipe-purging the only active track → active curricula count = 0 (BUG)
///   • The guard belongs in [ActiveCurriculumDao.deactivateByProfile], which
///     throws [DaoInvariantError] (code [DaoErrorCode.lastActiveCurriculum])
///     correctly — but the hub/detail bypass it.
///
/// After the fix, the hub/detail screens must call
/// [CurriculumActivationService.deactivate] (or check the count themselves)
/// before deleting, so the delete is blocked when it would remove the last
/// active curriculum.
///
/// N8 invariant: completion_events row count NEVER decreases after purge.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../helpers/drift_memory.dart'
    show inMemoryDb, seedProfile, seedTrack;

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── TRK-HUB-04: deleting the last active curriculum leaves 0 active curricula

  group('TRK-HUB-04: last-curriculum guard (hub/detail bypass)', () {
    test('soft-deleting the only active track leaves active-curricula count = 0 '
        '(exposes missing last-curriculum guard in hub/detail)', () async {
      // Seed exactly ONE active track — the last active curriculum.
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      // Verify precondition: 1 active curriculum.
      final before = await db.activeCurriculumDao.getActiveCurriculaByProfile(
        1,
      );
      expect(
        before,
        hasLength(1),
        reason: 'precondition: one active curriculum',
      );

      // Hub/detail bypass: call deleteTrackAndData directly (no guard).
      await db.trackDao.deleteTrackAndData(trackId);

      // After the delete, active curricula is now 0 — the profile is dead-ended.
      // This test documents the DEFECT: the hub/detail have no guard.
      final after = await db.activeCurriculumDao.getActiveCurriculaByProfile(1);
      expect(
        after,
        isEmpty,
        reason:
            'BUG (TRK-HUB-04): hub/detail bypass the last-curriculum guard; '
            'active curricula drops to 0 — dashboard dead-ends.',
      );
    });

    test('purging the only active track leaves active-curricula count = 0 '
        '(wipe path also lacks the last-curriculum guard)', () async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      final before = await db.activeCurriculumDao.getActiveCurriculaByProfile(
        1,
      );
      expect(before, hasLength(1));

      // Hub/detail wipe-bypass: purgeHistory with no guard.
      await db.trackDao.purgeHistory(trackId);

      final after = await db.activeCurriculumDao.getActiveCurriculaByProfile(1);
      expect(
        after,
        isEmpty,
        reason: 'BUG (TRK-HUB-04): wipe path also drops active curricula to 0.',
      );
    });

    test('deactivateByProfile throws DaoInvariantError on the last active '
        'curriculum (the guard that hub/detail must invoke before direct DAO '
        'calls)', () async {
      await seedTrack(db, profileId: 1, curriculumId: 'mishnayos');

      // The correct path (used by CurriculumActivationService.deactivate)
      // is guarded by deactivateByProfile which checks active count <= 1.
      // AUD-core-database-14 (EH-5) replaced the raw StateError this guard
      // used to throw with the typed, localizable DaoInvariantError.
      expect(
        () => db.activeCurriculumDao.deactivateByProfile(
          CurriculumId.mishnayos,
          1,
        ),
        throwsA(
          isA<DaoInvariantError>().having(
            (e) => e.code,
            'code',
            DaoErrorCode.lastActiveCurriculum,
          ),
        ),
        reason:
            'deactivateByProfile must throw DaoInvariantError('
            'DaoErrorCode.lastActiveCurriculum) when it would remove the '
            'last active curriculum — this is the guard the hub/detail '
            'bypass.',
      );
    });

    test('soft-deleting one of two active tracks preserves the other curriculum '
        '(delete is safe when not the last)', () async {
      // Two curricula active.
      final mishnayosTrackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await seedTrack(db, profileId: 1, curriculumId: 'bavli');

      final before = await db.activeCurriculumDao.getActiveCurriculaByProfile(
        1,
      );
      expect(before, hasLength(2));

      // Deleting one is safe.
      await db.trackDao.deleteTrackAndData(mishnayosTrackId);

      final after = await db.activeCurriculumDao.getActiveCurriculaByProfile(1);
      expect(
        after,
        hasLength(1),
        reason:
            'Deleting one of two active tracks should leave the other intact.',
      );
      expect(after.first, equals('bavli'));
    });
  });

  // ── N8 invariant: completion_events count never decreases after purge ───────

  group('N8 invariant: purge never decreases completion_events row count', () {
    test('purgeHistory stamps purgedAt on completions but does NOT remove rows '
        '(completion count must be equal before and after purge)', () async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      // Seed 3 completions for this track.
      for (var i = 1; i <= 3; i++) {
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot.${i}a',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: DateTime.utc(2026, 1, i),
          ),
        );
      }

      // Count before purge.
      final countBefore = await db.select(db.completionEvents).get();
      expect(countBefore, hasLength(3));

      await db.trackDao.purgeHistory(trackId);

      // Count after purge — must not decrease (N8 invariant).
      final countAfter = await db.select(db.completionEvents).get();
      expect(
        countAfter.length,
        greaterThanOrEqualTo(countBefore.length),
        reason:
            'N8: completion_events row count must never decrease after purge.',
      );
      expect(countAfter, hasLength(3));

      // Every row is tombstoned with purgedAt.
      for (final row in countAfter) {
        expect(
          row.purgedAt,
          isNotNull,
          reason:
              'Every completion for the purged track must have purgedAt set.',
        );
      }
    });

    test('soft-delete (archive) does NOT touch completion_events rows at all '
        '(completions survive with purgedAt = null)', () async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot.2a',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime.utc(2026, 1, 1),
        ),
      );

      await db.trackDao.deleteTrackAndData(trackId);

      final rows = await db.select(db.completionEvents).get();
      expect(
        rows,
        hasLength(1),
        reason: 'Archive must not remove completion rows.',
      );
      expect(
        rows.first.purgedAt,
        isNull,
        reason: 'Archive (soft-delete) must not stamp purgedAt on completions.',
      );
    });
  });
}
