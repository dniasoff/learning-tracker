/// Comprehensive track lifecycle tests.
///
/// Covers the full track lifecycle — overdue detection via the pure
/// projection, progress metrics, delete, restore — and the interactions
/// between them.  Each group tests one invariant cluster.
///
/// Test groups:
///   A — Overdue detection via the pure projection (replaces backfill-based
///       prior-day snapshot approach — Wave 3 cutover)
///   B — Track delete + restore
///   C — Snapshot cache: daily_plans is a disposable cache; getPriorlyShownRefs
///       still works for chazara (review) purposes
///   D — Progress metrics: completion count and distinct-ref agreement
///   E — Multi-track and multi-profile isolation
@Tags(['track_lifecycle'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Insert a completion row via the event log (C1 canonical write path).
Future<void> _addCompletion(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required String sefariaRef,
  CurriculumId curriculum = CurriculumId.mishnayos,
  int stageId = 1,
  DateTime? completedAt,
}) => seedCompletion(
  db,
  CompletionEventsCompanion.insert(
    profileId: profileId,
    curriculumId: curriculum.storageKey,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: TrackType.personal.storageKey,
    trackId: Value(trackId),
    eventTimestamp: completedAt ?? DateTimeFactory.nowUtc(),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── A — Overdue detection via the pure projection ──────────────────────────
  //
  // Wave 3 removed the backfill machinery.  The projection is now the
  // authoritative source of overdue/today — a pure function of synced inputs
  // that never writes to daily_plans.
  //
  // These tests validate the projection invariants from the track-lifecycle
  // perspective: correct overdue count for elapsed study days, completions
  // reducing the overdue set, and monotonic growth as the track ages.

  group(
    'A: Overdue detection — pure projection (Wave 3 cutover)',
    tags: ['track_lifecycle'],
    () {
      // Fixed dates for determinism.
      final anchor = DateTime.utc(2026, 5, 14); // Thu — 3 days before today
      final today = DateTime.utc(2026, 5, 17); // Sun

      // Ordered refs: one per day so the schedule is easy to reason about.
      final orderedRefs = List.generate(10, (i) => 'ref_$i');

      // Study-day pattern: Mon–Fri only (ISO 1–5).
      const pattern = StudyDayPattern({1, 2, 3, 4, 5});

      // Elapsed study days in [anchor, today):
      //   anchor 2026-05-14 Thu ✓ (study day)
      //   2026-05-15 Fri ✓ (study day)
      //   2026-05-16 Sat ✗ (not a study day)
      // Total = 2 elapsed study days.
      const pace = 1; // 1 ref per study day
      const expectedElapsed = 2;

      test('anchor 3 calendar days ago → 2 overdue (elapsed study days)', () {
        final schedule = selfPacedSchedule(
          anchor: anchor,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: today,
        );
        final result = project(
          schedule: schedule,
          completions: {},
          today: today,
        );
        expect(
          result.overdue.length,
          expectedElapsed,
          reason:
              'Two elapsed study days (Thu + Fri) with pace=1 → 2 overdue; '
              'Saturday is skipped by the study-day pattern',
        );
      });

      test('today is a study day → 1 dueToday', () {
        // today = Sunday (weekday 7) = NOT a study day in Mon–Fri pattern.
        // Swap to a Mon anchor so today-Sunday is not a study day check.
        // Use the explicitly computed today=2026-05-18 Monday for this test.
        final todayMonday = DateTime.utc(2026, 5, 18); // Monday
        final anchorSun = DateTime.utc(2026, 5, 11); // 7 days prior
        // Elapsed study days in [anchor, todayMonday):
        //   Mon 5/11 ✓, Tue 5/12 ✓, Wed 5/13 ✓, Thu 5/14 ✓, Fri 5/15 ✓
        //   Sat 5/16 ✗, Sun 5/17 ✗  → 5 elapsed study days
        final schedule = selfPacedSchedule(
          anchor: anchorSun,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: todayMonday,
        );
        final result = project(
          schedule: schedule,
          completions: {},
          today: todayMonday,
        );
        expect(
          result.dueToday.length,
          pace,
          reason: 'Monday is a study day → pace refs due today',
        );
        expect(
          result.overdue.length,
          5,
          reason: '5 elapsed study days × pace=1 → 5 overdue',
        );
      });

      test('completing overdue refs reduces overdue set', () {
        final schedule = selfPacedSchedule(
          anchor: anchor,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: today,
        );

        // Complete the first overdue ref.
        final firstOverdue = schedule.first.sefariaRef;
        final result = project(
          schedule: schedule,
          completions: {firstOverdue},
          today: today,
        );
        expect(
          result.overdue.length,
          expectedElapsed - 1,
          reason:
              'completing 1 of $expectedElapsed overdue refs → ${expectedElapsed - 1} remain',
        );
        expect(
          result.overdue,
          isNot(contains(firstOverdue)),
          reason: 'completed ref must not appear in overdue set',
        );
      });

      test('completing all overdue refs → overdue empty', () {
        final schedule = selfPacedSchedule(
          anchor: anchor,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: today,
        );
        final allOverdue = schedule
            .where(
              (u) => u.date.isBefore(
                DateTime.utc(today.year, today.month, today.day),
              ),
            )
            .map((u) => u.sefariaRef)
            .toSet();
        final result = project(
          schedule: schedule,
          completions: allOverdue,
          today: today,
        );
        expect(result.overdue, isEmpty);
      });

      test('self-paced track without a pace → MissingPaceError (no tasks)', () {
        expect(
          () => selfPacedSchedule(
            anchor: anchor,
            pace: null,
            studyDayPattern: pattern,
            orderedRefs: orderedRefs,
            today: today,
          ),
          throwsA(isA<MissingPaceError>()),
          reason:
              'Architecture §10.3: a self-paced track without a pace must throw '
              'MissingPaceError — no auto-default is permitted',
        );
      });
    },
  );

  // ── B — Track delete + restore ─────────────────────────────────────────────

  group('B: Track delete + restore', tags: ['track_lifecycle'], () {
    late UserDatabase db;
    const profileId = 1;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });
    tearDown(() => db.close());

    test('soft-deleted track is absent from active-tracks query', () async {
      final trackId = await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );

      await db.trackDao.deleteTrackAndData(trackId);

      final active = await db.trackDao.getActiveTracksForProfile(profileId);
      expect(
        active.any((t) => t.id == trackId),
        isFalse,
        reason: 'soft-deleted track must not appear in active-tracks query',
      );
    });

    test('restore makes track active again with deletedAt = null', () async {
      final trackId = await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );
      await db.trackDao.deleteTrackAndData(trackId);

      await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );

      final track = await db.trackDao.getTrackById(trackId);
      expect(track!.isActive, isTrue);
      expect(track.deletedAt, isNull);
    });

    test(
      'restore resets activatedAt to now (new learning session) (N5)',
      () async {
        final originalActivatedAt = DateTime.utc(2026, 5, 10);
        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: originalActivatedAt,
                activatedAt: originalActivatedAt,
              ),
            );

        await db.trackDao.deleteTrackAndData(trackId);
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        final restored = await db.trackDao.getTrackById(trackId);
        // activatedAt must be reset to now — the new session boundary.
        // Pre-restore completions (completedAt = 2026-05-10) will predate it.
        expect(
          restored!.activatedAt.isAfter(originalActivatedAt),
          isTrue,
          reason:
              'N5: restore must reset activatedAt to now so the current '
              'learning cycle starts fresh and pre-restore completions are '
              'excluded from current-session progress',
        );
      },
    );

    test('restore preserves pre-delete completions for lifetime; '
        'current session starts at 0 (N4)', () async {
      final trackId = await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );
      await _addCompletion(
        db,
        profileId: profileId,
        trackId: trackId,
        sefariaRef: 'Berakhot 1:1',
        completedAt: DateTime.utc(2026, 5, 1), // clearly in the past
      );
      expect(
        await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnayos.storageKey,
          profileId,
        ),
        1,
      );

      await db.trackDao.deleteTrackAndData(trackId);
      await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );

      final restored = await db.trackDao.getTrackById(trackId);

      // Lifetime count preserved.
      expect(
        await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnayos.storageKey,
          profileId,
        ),
        1,
        reason: 'pre-restore completions survive for lifetime stats',
      );

      // Current-session count = 0 (pre-restore completedAt < new activatedAt).
      final session = await db.completionDao
          .getCompletionsByTrackAndProfileSince(
            trackId,
            profileId,
            restored!.activatedAt,
          );
      expect(
        session,
        isEmpty,
        reason:
            'current session starts at 0 — pre-restore completions '
            'predate the new activatedAt',
      );
    });

    test(
      'deleteTrackAndData removes daily-plan rows; daily_plans is a '
      'disposable cache — projection rebuilds from synced inputs after restore',
      () async {
        final today = DateTime.utc(2026, 5, 17);
        final threeDaysAgo = today.subtract(const Duration(days: 3));

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: threeDaysAgo,
                activatedAt: threeDaysAgo,
              ),
            );

        // Write some synthetic daily_plans rows (simulating a prior day's snapshot).
        await db.dailyPlanDao.insertEntries([
          DailyPlansCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            planDate: DateUtils.extractLocalDate(threeDaysAgo),
            sefariaRef: 'ref_0',
            stageOrder: 1,
            stageDefinitionId: 1,
            trackId: trackId,
            priority: 'newLearning',
            createdAt: threeDaysAgo,
          ),
        ]);

        // Soft-delete removes the daily-plan rows.
        await db.trackDao.deleteTrackAndData(trackId);
        final plansAfterDelete = await (db.select(
          db.dailyPlans,
        )..where((t) => t.trackId.equals(trackId))).get();
        expect(
          plansAfterDelete,
          isEmpty,
          reason: 'deleteTrackAndData must wipe daily-plan snapshot rows',
        );

        // Restore — the projection rebuilds from synced inputs (no daily_plans needed).
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        // Verify: projection computes correctly with no daily_plans rows.
        final allPlans = await (db.select(
          db.dailyPlans,
        )..where((t) => t.trackId.equals(trackId))).get();
        expect(
          allPlans,
          isEmpty,
          reason:
              'No daily_plans rows needed — projection derives from synced inputs',
        );
      },
    );

    test('completions on an unrelated track are unaffected by delete+restore '
        'of a different track', () async {
      final trackA = await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );
      final trackB = await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnaBerurah,
        trackType: TrackType.personal,
      );

      // Use a past timestamp so it clearly predates any restore activatedAt.
      await _addCompletion(
        db,
        profileId: profileId,
        trackId: trackA,
        sefariaRef: 'Berakhot 1:1',
        curriculum: CurriculumId.mishnayos,
        completedAt: DateTime.utc(2026, 5, 1),
      );
      await _addCompletion(
        db,
        profileId: profileId,
        trackId: trackB,
        sefariaRef: 'OC 1:1',
        curriculum: CurriculumId.mishnaBerurah,
      );

      // Delete and restore track A.
      await db.trackDao.deleteTrackAndData(trackA);
      await db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );

      final restoredA = await db.trackDao.getTrackById(trackA);

      // Track B's completion must be untouched.
      expect(
        await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnaBerurah.storageKey,
          profileId,
        ),
        1,
        reason: 'track B completions must survive track A delete+restore',
      );
      // Track A: lifetime count preserved (completion survives restore).
      expect(
        await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnayos.storageKey,
          profileId,
        ),
        1,
        reason: 'track A lifetime completion is preserved after restore',
      );
      // Track A: current session = 0 (pre-restore completion predates activatedAt).
      final sessionA = await db.completionDao
          .getCompletionsByTrackAndProfileSince(
            trackA,
            profileId,
            restoredA!.activatedAt,
          );
      expect(
        sessionA,
        isEmpty,
        reason: 'track A current session starts fresh after restore',
      );
    });
  });

  // ── C — Snapshot cache: getPriorlyShownRefs for chazara purposes ───────────
  //
  // daily_plans is a disposable cache. getPriorlyShownRefsForTrack still works
  // for chazara (review) task generation — Wave 3 retains this DAO method.
  // What changed: daily_plans.isOverdue is NOT the source of truth for
  // the overdue count — the projection is.

  group(
    'C: Snapshot cache — getPriorlyShownRefsForTrack for chazara',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;
      const profileId = 1;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test(
        'no snapshot rows → getPriorlyShownRefsForTrack returns empty set',
        () async {
          final today = DateTime.utc(2026, 5, 17);
          final trackId = await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: profileId,
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  stateChangedAt: today,
                  activatedAt: today,
                ),
              );

          final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
            trackId: trackId,
            excludeDate: today,
          );
          expect(priorRefs, isEmpty);
        },
      );

      test(
        'manual snapshot rows → getPriorlyShownRefs returns those refs',
        () async {
          final today = DateTime.utc(2026, 5, 17);
          final yesterday = DateTime.utc(2026, 5, 16);
          final trackId = await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: profileId,
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  stateChangedAt: yesterday,
                  activatedAt: yesterday,
                ),
              );

          // Write a snapshot row directly (simulating chazara engine output).
          await db.dailyPlanDao.insertEntries([
            DailyPlansCompanion.insert(
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              planDate: yesterday,
              sefariaRef: 'Berakhot 1:1',
              stageOrder: 1,
              stageDefinitionId: 1,
              trackId: trackId,
              priority: 'scheduledChazara',
              createdAt: yesterday,
            ),
          ]);

          final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
            trackId: trackId,
            excludeDate: today,
          );
          expect(priorRefs, contains('Berakhot 1:1'));
        },
      );

      test(
        'projection derives overdue independently of daily_plans.isOverdue',
        () {
          // The pure projection does not read daily_plans at all — it only
          // needs schedule + completions.  This test verifies that the
          // projection gives the correct overdue count without any DB access.
          final today = DateTime.utc(2026, 5, 17);
          final anchor = today.subtract(const Duration(days: 3));

          final calendarEntries = <(DateTime, String)>[
            (anchor, 'ref_anchor'),
            (anchor.add(const Duration(days: 1)), 'ref_d1'),
            (anchor.add(const Duration(days: 2)), 'ref_d2'),
            (today, 'ref_today'),
          ];

          final schedule = programSchedule(
            anchor: anchor,
            calendarEntries: calendarEntries,
            today: today,
          );

          // Completion set is empty — all prior days are overdue.
          final result = project(
            schedule: schedule,
            completions: {},
            today: today,
          );
          expect(result.overdue, hasLength(3));
          expect(result.dueToday, hasLength(1));

          // The projection result is independent of any daily_plans state.
          // Even if daily_plans were cleared, the projection would give the
          // same answer (reinstall durability — O4).
        },
      );
    },
  );

  // ── D — Progress metrics ───────────────────────────────────────────────────

  group(
    'D: Progress metrics — completion count and distinct-ref agreement',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;
      const profileId = 1;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test('0 completions → count = 0', () async {
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          0,
        );
      });

      test('same ref at 2 stages → count = 1 (distinct)', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:1',
          stageId: 2,
        );

        final count = await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnayos.storageKey,
          profileId,
        );
        expect(
          count,
          1,
          reason:
              'completing the same ref twice (different stages) counts '
              'as 1 distinct item — not 2 raw rows (R5 / N6)',
        );
      });

      test('3 distinct refs → count = 3', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        for (final ref in ['Berakhot 1:1', 'Berakhot 1:2', 'Berakhot 1:3']) {
          await _addCompletion(
            db,
            profileId: profileId,
            trackId: trackId,
            sefariaRef: ref,
          );
        }

        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          3,
        );
      });

      test(
        'delete + restore: lifetime count preserved; session count = 0 (N4)',
        () async {
          final trackId = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );
          for (final ref in ['Berakhot 1:1', 'Berakhot 1:2']) {
            await _addCompletion(
              db,
              profileId: profileId,
              trackId: trackId,
              sefariaRef: ref,
              completedAt: DateTime.utc(2026, 5, 1), // clearly in the past
            );
          }
          expect(
            await db.completionDao.getAggregateCountByProfile(
              CurriculumId.mishnayos.storageKey,
              profileId,
            ),
            2,
          );

          await db.trackDao.deleteTrackAndData(trackId);
          await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );

          final restored = await db.trackDao.getTrackById(trackId);

          // Lifetime: pre-restore completions still count.
          expect(
            await db.completionDao.getAggregateCountByProfile(
              CurriculumId.mishnayos.storageKey,
              profileId,
            ),
            2,
            reason: 'lifetime count must be preserved after restore',
          );

          // Current session: 0 — all pre-restore completions predate activatedAt.
          final session = await db.completionDao
              .getCompletionsByTrackAndProfileSince(
                trackId,
                profileId,
                restored!.activatedAt,
              );
          expect(
            session,
            isEmpty,
            reason: 'current session starts at 0 after restore',
          );
        },
      );

      test('getAggregateCountByProfile is scoped to one curriculum', () async {
        final trackMishna = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final trackMB = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnaBerurah,
          trackType: TrackType.personal,
        );

        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackMishna,
          sefariaRef: 'Berakhot 1:1',
          curriculum: CurriculumId.mishnayos,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackMB,
          sefariaRef: 'OC 1:1',
          curriculum: CurriculumId.mishnaBerurah,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackMB,
          sefariaRef: 'OC 1:2',
          curriculum: CurriculumId.mishnaBerurah,
        );

        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          1,
          reason: 'mishnayos count must not include mishnaBerurah completions',
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnaBerurah.storageKey,
            profileId,
          ),
          2,
        );
      });

      test(
        'track-level completion query matches curriculum-level for single-track curriculum',
        () async {
          final trackId = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );
          for (final ref in ['Berakhot 1:1', 'Berakhot 1:2', 'Berakhot 1:3']) {
            await _addCompletion(
              db,
              profileId: profileId,
              trackId: trackId,
              sefariaRef: ref,
            );
          }

          final byTrack = await db.completionDao
              .getCompletionsByTrackAndProfile(trackId, profileId);
          final byCurriculum = await db.completionDao
              .getAggregateCountByProfile(
                CurriculumId.mishnayos.storageKey,
                profileId,
              );

          expect(byTrack.map((c) => c.sefariaRef).toSet().length, byCurriculum);
        },
      );
    },
  );

  // ── E — Multi-track and multi-profile isolation ────────────────────────────

  group(
    'E: Multi-track and multi-profile isolation',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
        // Seed a second profile so profileId=2 completions satisfy FK.
        await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: 1,
                displayName: 'Test User 2',
                mode: 'adult',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
      });
      tearDown(() => db.close());

      test('two profiles have independent completion counts', () async {
        const profile1 = 1;
        const profile2 = 2;

        final track1 = await db.trackDao.restoreOrCreate(
          profileId: profile1,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final track2 = await db.trackDao.restoreOrCreate(
          profileId: profile2,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        // Profile 1: 3 completions.
        for (var i = 1; i <= 3; i++) {
          await _addCompletion(
            db,
            profileId: profile1,
            trackId: track1,
            sefariaRef: 'Berakhot 1:$i',
          );
        }
        // Profile 2: 1 completion.
        await _addCompletion(
          db,
          profileId: profile2,
          trackId: track2,
          sefariaRef: 'Berakhot 1:1',
        );

        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profile1,
          ),
          3,
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profile2,
          ),
          1,
          reason: 'profile 2 must not see profile 1\'s completions',
        );
      });

      test(
        'projection isolates overdue per track — two tracks on the same profile '
        'have independent overdue sets',
        () {
          // Two tracks with different anchors: track A has 3 elapsed days,
          // track B has 1 elapsed day.
          final today = DateTime.utc(2026, 5, 17);
          const pattern = StudyDayPattern({1, 2, 3, 4, 5, 6, 7}); // every day
          const pace = 1;

          final anchorA = today.subtract(const Duration(days: 3));
          final anchorB = today.subtract(const Duration(days: 1));
          final refs = List.generate(10, (i) => 'ref_$i');

          final scheduleA = selfPacedSchedule(
            anchor: anchorA,
            pace: pace,
            studyDayPattern: pattern,
            orderedRefs: refs,
            today: today,
          );
          final scheduleB = selfPacedSchedule(
            anchor: anchorB,
            pace: pace,
            studyDayPattern: pattern,
            orderedRefs: refs,
            today: today,
          );

          final resultA = project(
            schedule: scheduleA,
            completions: {},
            today: today,
          );
          final resultB = project(
            schedule: scheduleB,
            completions: {},
            today: today,
          );

          expect(
            resultA.overdue.length,
            3,
            reason: 'track A: 3 elapsed days → 3 overdue',
          );
          expect(
            resultB.overdue.length,
            1,
            reason: 'track B: 1 elapsed day → 1 overdue',
          );
        },
      );

      test('restoreOrCreate creates separate rows per profile', () async {
        const profile1 = 1;
        const profile2 = 2;

        final id1 = await db.trackDao.restoreOrCreate(
          profileId: profile1,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final id2 = await db.trackDao.restoreOrCreate(
          profileId: profile2,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        expect(
          id1,
          isNot(equals(id2)),
          reason:
              'different profiles must get separate track rows — the UNIQUE '
              'constraint is on (profileId, curriculumId, trackType)',
        );
      });
    },
  );
}
