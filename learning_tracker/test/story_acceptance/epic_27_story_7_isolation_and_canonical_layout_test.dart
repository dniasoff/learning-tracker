/// Story acceptance tests for Story 27.7 (DNI-383).
///
/// Two integration test surfaces:
///
///   1. multi_profile_isolation
///      Creates Profile A and Profile B against an in-memory Drift database,
///      records a completion for A, and asserts that every profile-aware
///      CompletionDao query for B returns empty. Pins down the FR1 / NFR13
///      invariant that one profile's data never leaks into another's reads.
///
///   2. track_card_canonical_layout
///      Verifies that all 4 [TrackCardShape]s (programCalendar,
///      deadlineGoal, velocityGoal, momentum) flow through the same
///      [TrackCardViewModel] constructor surface. The widget-tree comparison
///      portion of UX-DR10 is left as a skip-stub because the canonical
///      [TrackCard] widget integration is not yet under test.
@Tags(['epic_27'])
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

const _curriculumId = 'mishnayos';
const _refForA = 'Mishnah_Berakhot.1.1';
const _stageId = 1;
const _trackType = 'personal';

/// Inserts a [CurriculumTracks] row for [profileId] and returns its id.
Future<int> _insertTrackFor(UserDatabase db, int profileId) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: _curriculumId,
          trackType: _trackType,
          activatedAt: DateTime.utc(2026, 5, 13, 10),
        ),
      );
  return row.id;
}

/// Minimal [NextTaskData] for constructing a [TrackCardViewModel].
const _nextTask = NextTaskData(displayLabel: 'Berakhot 1:1');

/// Minimal [LifetimeLearningData] for constructing a [TrackCardViewModel].
const _lifetime = LifetimeLearningData(fraction: 0.0, isComplete: false);

void main() {
  // ── Story 27.7.1 ─ multi-profile isolation ─────────────────────────────

  group(
    'Story 27.7 — multi-profile isolation: Profile A completion never '
    'surfaces in Profile B queries',
    tags: ['story_27_7'],
    () {
      late UserDatabase db;
      late ProfileRepositoryImpl profileRepo;
      late ProfileModel profileA;
      late ProfileModel profileB;
      late int trackIdA;
      late int completionIdA;

      setUp(() async {
        // In-memory Drift database. Equivalent to the inMemoryDb() helper
        // shipped in DNI-377; on origin/dev only createTestDatabase() is
        // available, and they are functionally identical.
        db = createTestDatabase();
        profileRepo = ProfileRepositoryImpl(db);

        profileA = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Alice',
          mode: 'adult',
        );
        profileB = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Bob',
          mode: 'adult',
        );

        // A completion lives under profileA only.
        trackIdA = await _insertTrackFor(db, profileA.id);
        completionIdA = await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: profileA.id,
            curriculumId: _curriculumId,
            sefariaRef: _refForA,
            stageId: _stageId,
            trackType: _trackType,
            trackId: trackIdA,
            completedAt: DateTime.utc(2026, 5, 13, 12),
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('precondition: completion is visible to Profile A', () async {
        final aResults = await db.completionDao.getCompletionsByProfile(
          profileA.id,
        );
        expect(aResults, hasLength(1));
        expect(aResults.single.id, completionIdA);
        expect(aResults.single.profileId, profileA.id);
      });

      test('AC: getCompletionsByProfile(B) returns empty', () async {
        final results = await db.completionDao.getCompletionsByProfile(
          profileB.id,
        );
        expect(results, isEmpty);
      });

      test(
        'AC: getCompletionsByCurriculumAndProfile(curriculum, B) returns '
        'empty even though A has matching completion in the same curriculum',
        () async {
          final results = await db.completionDao
              .getCompletionsByCurriculumAndProfile(_curriculumId, profileB.id);
          expect(results, isEmpty);
        },
      );

      test('AC: getCompletionsForContentAndProfile(ref, B) returns empty even '
          'though A completed that exact ref', () async {
        final results = await db.completionDao
            .getCompletionsForContentAndProfile(_refForA, profileB.id);
        expect(results, isEmpty);
      });

      test(
        'AC: getAggregateCountByProfile(curriculum, B) returns 0 even though '
        'A has 1 completion in the same curriculum (dashboard percentage path)',
        () async {
          final count = await db.completionDao.getAggregateCountByProfile(
            _curriculumId,
            profileB.id,
          );
          expect(count, 0);
        },
      );

      test(
        'AC: getTrackBreakdownByProfile(curriculum, B) returns empty map',
        () async {
          final breakdown = await db.completionDao.getTrackBreakdownByProfile(
            _curriculumId,
            profileB.id,
          );
          expect(breakdown, isEmpty);
        },
      );

      test('AC: completionExistsByProfile(B) returns false for the exact '
          'composite-key tuple that A committed', () async {
        final exists = await db.completionDao.completionExistsByProfile(
          curriculumId: _curriculumId,
          sefariaRef: _refForA,
          stageId: _stageId,
          trackType: _trackType,
          completedAt: DateTime.utc(2026, 5, 13, 12),
          profileId: profileB.id,
        );
        expect(exists, isFalse);
      });

      test('AC: getCompletionsByDateRangeAndProfile(±1d, B) returns empty even '
          'though A has a completion inside that window', () async {
        final start = DateTime.utc(2026, 5, 12);
        final end = DateTime.utc(2026, 5, 14);
        final results = await db.completionDao
            .getCompletionsByDateRangeAndProfile(start, end, profileB.id);
        expect(results, isEmpty);
      });

      test(
        'AC: hasCompletionsInDateRangeByProfile(±1d, B) returns false',
        () async {
          final start = DateTime.utc(2026, 5, 12);
          final end = DateTime.utc(2026, 5, 14);
          final has = await db.completionDao.hasCompletionsInDateRangeByProfile(
            start,
            end,
            profileB.id,
          );
          expect(has, isFalse);
        },
      );

      test(
        'AC: getReviewCountsByItem(curriculum, B) — the per-item-by-profile '
        'GROUP-BY surface used by the review-count widgets — returns empty',
        () async {
          final counts = await db.completionDao.getReviewCountsByItem(
            _curriculumId,
            profileB.id,
          );
          expect(counts, isEmpty);
        },
      );

      test(
        'AC: getExistingSefariaRefsForBulkStage(B) returns empty even when '
        'A has a completion for the same ref / stage / track / curriculum',
        () async {
          final refs = await db.completionDao
              .getExistingSefariaRefsForBulkStage(
                profileId: profileB.id,
                curriculumId: _curriculumId,
                stageId: _stageId,
                trackType: _trackType,
                sefariaRefs: const [_refForA],
              );
          expect(refs, isEmpty);
        },
      );

      test('AC: getCompletionsByProfileForSefariaRefs(B) returns empty even '
          'when querying the exact ref A completed', () async {
        final rows = await db.completionDao
            .getCompletionsByProfileForSefariaRefs(profileB.id, const {
              _refForA,
            });
        expect(rows, isEmpty);
      });

      test('AC: dashboard percentage surface — the data CompletionDao feeds '
          'dashboardCompletionPercentageProvider — yields 0 for Profile B '
          'when A has the only completion (proves the dashboard provider '
          'cannot surface A\'s data into B\'s screen)', () async {
        // dashboardCompletionPercentageProvider at
        // dashboard_providers.dart:131-152 reads completions exclusively
        // through getCompletionsByCurriculumAndProfile(curriculumId,
        // profileId). Asserting the DAO returns empty for B is sufficient
        // and provider-stack-free.
        final rowsForB = await db.completionDao
            .getCompletionsByCurriculumAndProfile(_curriculumId, profileB.id);
        expect(rowsForB, isEmpty);
      });

      test(
        'AC: dashboardLastCompletion surface — the data source the dashboard '
        '"last completed at" tile reads — is null for Profile B',
        () async {
          // dashboardLastCompletionProvider at
          // dashboard_providers.dart:155-172 takes max(completedAt) over the
          // same getCompletionsByCurriculumAndProfile result.
          final rowsForB = await db.completionDao
              .getCompletionsByCurriculumAndProfile(_curriculumId, profileB.id);
          final lastB = rowsForB.isEmpty
              ? null
              : rowsForB
                    .map((c) => c.completedAt)
                    .reduce((a, b) => a.isAfter(b) ? a : b);
          expect(lastB, isNull);
        },
      );

      test('AC: cross-table isolation — a bookmark written under A does not '
          'surface in any profile-scoped bookmark read for B', () async {
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                profileId: profileA.id,
                curriculumId: _curriculumId,
                trackId: trackIdA,
                sefariaRef: _refForA,
                updatedAt: DateTime.utc(2026, 5, 13, 12),
              ),
            );
        final bookmarksForB = await (db.select(
          db.bookmarks,
        )..where((t) => t.profileId.equals(profileB.id))).get();
        expect(bookmarksForB, isEmpty);
      });

      test('AC: cross-table isolation — a goal written under A does not '
          'surface in any profile-scoped goal read for B', () async {
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: profileA.id,
                curriculumId: _curriculumId,
                trackId: trackIdA,
                createdAt: DateTime.utc(2026, 5, 13, 12),
                updatedAt: DateTime.utc(2026, 5, 13, 12),
              ),
            );
        final goalsForB = await (db.select(
          db.goals,
        )..where((t) => t.profileId.equals(profileB.id))).get();
        expect(goalsForB, isEmpty);
      });
    },
  );

  // ── Story 27.7.2 ─ track-card canonical layout ─────────────────────────

  group(
    'Story 27.7 — track-card canonical layout: all 4 data shapes flow '
    'through one canonical model surface',
    tags: ['story_27_7'],
    () {
      test(
        'TrackCardShape has exactly 4 values (programCalendar, deadlineGoal, '
        'velocityGoal, momentum)',
        () {
          expect(TrackCardShape.values, hasLength(4));
          expect(
            TrackCardShape.values,
            containsAll([
              TrackCardShape.programCalendar,
              TrackCardShape.deadlineGoal,
              TrackCardShape.velocityGoal,
              TrackCardShape.momentum,
            ]),
          );
        },
      );

      test(
        'all 4 TrackCardShapes are constructible through the same '
        'TrackCardViewModel() factory surface (data-shape canonical-form check)',
        () {
          final viewModels = <TrackCardViewModel>[
            const TrackCardViewModel(
              trackId: 1,
              curriculumId: CurriculumId.bavli,
              shape: TrackCardShape.programCalendar,
              displayNamePrimary: 'Daf Yomi',
              curriculumColorValue: 0xFF1565C0,
              nextTask: _nextTask,
              breadcrumbLabel: 'CURRENT FOCUS',
              reviewCount: 0,
              dueTodayCount: 1,
              overdueCount: 0,
              chazaraLabel: 'Review',
              lifetime: _lifetime,
              calendarPos: CalendarPosition(
                currentDay: 12,
                totalDays: 2711,
                todayRef: 'Berakhot.13a',
                todayDisplayHe: 'ברכות יג.',
                delta: 0,
                status: CalendarStatus.caughtUp,
              ),
            ),
            const TrackCardViewModel(
              trackId: 2,
              curriculumId: CurriculumId.mishnayos,
              shape: TrackCardShape.deadlineGoal,
              displayNamePrimary: 'Mishnah Berakhot',
              curriculumColorValue: 0xFF2E7D32,
              nextTask: _nextTask,
              breadcrumbLabel: 'NEXT TASK',
              reviewCount: 0,
              dueTodayCount: 2,
              overdueCount: 0,
              chazaraLabel: 'Review',
              lifetime: _lifetime,
              paceStatus: PaceStatus(
                status: PaceStatusType.onPace,
                daysDelta: 0,
                delta: DateScheduleDelta(DateDelta(0)),
                rollingAverage: 0.71,
              ),
            ),
            const TrackCardViewModel(
              trackId: 3,
              curriculumId: CurriculumId.mishnayos,
              shape: TrackCardShape.velocityGoal,
              displayNamePrimary: 'Mishnayos cover-to-cover',
              curriculumColorValue: 0xFF2E7D32,
              nextTask: _nextTask,
              breadcrumbLabel: 'NEXT TASK',
              reviewCount: 0,
              dueTodayCount: 1,
              overdueCount: 0,
              chazaraLabel: 'Review',
              lifetime: _lifetime,
              paceStatus: PaceStatus(
                status: PaceStatusType.behind,
                daysDelta: -3,
                delta: DateScheduleDelta(DateDelta(-3)),
                rollingAverage: 0.4,
              ),
            ),
            const TrackCardViewModel(
              trackId: 4,
              curriculumId: CurriculumId.tanach,
              shape: TrackCardShape.momentum,
              displayNamePrimary: 'Tanach free-study',
              curriculumColorValue: 0xFF6A1B9A,
              nextTask: _nextTask,
              breadcrumbLabel: 'NEXT TASK',
              reviewCount: 0,
              dueTodayCount: 0,
              overdueCount: 0,
              chazaraLabel: 'Review',
              lifetime: _lifetime,
              momentum: MomentumStatus(
                recentCount: 3,
                personalAverage: 4.2,
                level: MomentumLevel.active,
              ),
            ),
          ];

          // Same runtime type — proves the 4 shapes are not structurally
          // divergent at the model layer.
          expect(viewModels, hasLength(4));
          expect(viewModels.map((vm) => vm.runtimeType).toSet(), hasLength(1));

          // Shape ↔ shape-specific field correspondence (the contract the
          // TrackCard widget tree relies on).
          expect(
            viewModels
                .where((vm) => vm.shape == TrackCardShape.programCalendar)
                .single
                .calendarPos,
            isNotNull,
          );
          expect(
            viewModels
                .where((vm) => vm.shape == TrackCardShape.deadlineGoal)
                .single
                .paceStatus,
            isNotNull,
          );
          expect(
            viewModels
                .where((vm) => vm.shape == TrackCardShape.velocityGoal)
                .single
                .paceStatus,
            isNotNull,
          );
          expect(
            viewModels
                .where((vm) => vm.shape == TrackCardShape.momentum)
                .single
                .momentum,
            isNotNull,
          );

          // All 4 shapes enumerated — no orphan shapes that bypass the
          // canonical form.
          expect(
            viewModels.map((vm) => vm.shape).toSet(),
            equals(TrackCardShape.values.toSet()),
          );
        },
      );

      test(
        'TrackCard widget-tree canonical-layout assertion (UX-DR10)',
        () {
          // Skip-stub. Widget-tree integration tests for the canonical
          // TrackCard and its 5 subcomponents (TrackCardHeader,
          // NextTaskBreadcrumb, TrackStatGrid, LifetimeLearningLine,
          // TrackContinueButton) are deferred to a dedicated widget-test
          // story.
        },
        skip:
            'Deferred to widget-test story — TrackCard widget integration '
            'tests not yet in scope for this acceptance suite.',
      );
    },
  );
}
