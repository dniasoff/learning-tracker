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
///      Verifies that all 4 [TrackProgressVariant]s (programCalendar,
///      deadlineGoal, velocityGoal, momentum) flow through the same
///      [TrackProgress] constructor surface. The widget-tree comparison
///      portion of UX-DR10 is left as a skip-stub because the canonical
///      [TrackCard] / [TrackCardViewModel] freezed value type is built by
///      Story 26.6 / DNI-388 and is not yet on dev. Activated once 26.6
///      lands.
@Tags(['epic_27'])
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
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
      // The widget-tree comparison that UX-DR10 ultimately demands operates
      // on the freezed `TrackCardViewModel` value type and the 5
      // subcomponents listed under Story 26.6 (TrackCardHeader,
      // NextTaskBreadcrumb, TrackStatGrid, LifetimeLearningLine,
      // TrackContinueButton). None of those exist on origin/dev yet — Story
      // 26.6 / DNI-388 (Epic 26) builds them.
      //
      // The shape-level half of the AC can be asserted today against
      // `TrackProgress`, which already enumerates the 4 variants and is the
      // single data-shape surface the future TrackCardViewModel composes
      // from. Asserting that all 4 variants pass through the same
      // constructor with shape-specific optional fields pins down the
      // "differs only in data, not in structure" invariant at the model
      // layer.

      test(
        'all 4 TrackProgressVariants are constructible through the same '
        'TrackProgress() factory surface (data-shape canonical-form check)',
        () {
          final variants = <TrackProgress>[
            const TrackProgress(
              trackId: 1,
              trackLabel: 'Daf Yomi',
              curriculumId: CurriculumId.bavli,
              variant: TrackProgressVariant.programCalendar,
              completedItems: 12,
              totalItems: 2711,
              scopePercentage: 12 / 2711,
              calendarPos: CalendarPosition(
                currentDay: 12,
                totalDays: 2711,
                todayRef: 'Berakhot.13a',
                todayDisplayHe: 'ברכות יג.',
                delta: 0,
                status: CalendarStatus.caughtUp,
              ),
              tasksToday: 1,
            ),
            const TrackProgress(
              trackId: 2,
              trackLabel: 'Mishnah Berakhot',
              curriculumId: CurriculumId.mishnayos,
              variant: TrackProgressVariant.deadlineGoal,
              completedItems: 30,
              totalItems: 100,
              scopePercentage: 0.30,
              paceStatus: PaceStatus(
                status: PaceStatusType.onPace,
                daysDelta: 0,
                delta: DateScheduleDelta(DateDelta(0)),
                rollingAverage: 0.71,
              ),
              tasksToday: 2,
            ),
            const TrackProgress(
              trackId: 3,
              trackLabel: 'Mishnayos cover-to-cover',
              curriculumId: CurriculumId.mishnayos,
              variant: TrackProgressVariant.velocityGoal,
              completedItems: 100,
              totalItems: 4192,
              scopePercentage: 100 / 4192,
              paceStatus: PaceStatus(
                status: PaceStatusType.behind,
                daysDelta: -3,
                delta: DateScheduleDelta(DateDelta(-3)),
                rollingAverage: 0.4,
              ),
              tasksToday: 1,
            ),
            const TrackProgress(
              trackId: 4,
              trackLabel: 'Tanach free-study',
              curriculumId: CurriculumId.tanach,
              variant: TrackProgressVariant.momentum,
              completedItems: 8,
              totalItems: 929,
              scopePercentage: 8 / 929,
              momentum: MomentumStatus(
                recentCount: 3,
                personalAverage: 4.2,
                level: MomentumLevel.active,
              ),
              tasksToday: 0,
            ),
          ];

          // Same runtime type — proves the 4 shapes are not structurally
          // divergent at the model layer.
          expect(variants, hasLength(4));
          expect(variants.map((p) => p.runtimeType).toSet(), hasLength(1));

          // Variant ↔ shape-specific field correspondence (the contract the
          // future TrackCardViewModel composer relies on).
          expect(
            variants
                .where((p) => p.variant == TrackProgressVariant.programCalendar)
                .single
                .calendarPos,
            isNotNull,
          );
          expect(
            variants
                .where((p) => p.variant == TrackProgressVariant.deadlineGoal)
                .single
                .paceStatus,
            isNotNull,
          );
          expect(
            variants
                .where((p) => p.variant == TrackProgressVariant.velocityGoal)
                .single
                .paceStatus,
            isNotNull,
          );
          expect(
            variants
                .where((p) => p.variant == TrackProgressVariant.momentum)
                .single
                .momentum,
            isNotNull,
          );

          // All 4 variants enumerated — no orphan shapes that bypass the
          // canonical form.
          expect(
            variants.map((p) => p.variant).toSet(),
            equals(TrackProgressVariant.values.toSet()),
          );
        },
      );

      test('resolveVariant() routes (programId, goalType) tuples to the 4 '
          'canonical variants — pins UX-DR10 routing logic for the future '
          'TrackCardViewModel composer', () {
        expect(
          resolveVariant(programId: 42, goalType: null),
          TrackProgressVariant.programCalendar,
        );
        expect(
          resolveVariant(programId: 42, goalType: 'deadline'),
          TrackProgressVariant.programCalendar,
          reason:
              'A program track always wins, even when goalType is set — '
              'the permutation matrix gates programId first.',
        );
        expect(
          resolveVariant(programId: null, goalType: 'deadline'),
          TrackProgressVariant.deadlineGoal,
        );
        expect(
          resolveVariant(programId: null, goalType: 'pace'),
          TrackProgressVariant.velocityGoal,
        );
        expect(
          resolveVariant(programId: null, goalType: null),
          TrackProgressVariant.momentum,
        );
        expect(
          resolveVariant(programId: null, goalType: 'unknown'),
          TrackProgressVariant.momentum,
          reason: 'Unrecognised goalType falls through to momentum.',
        );
      });

      test(
        'TrackCard widget-tree canonical-layout assertion (UX-DR10)',
        () {
          // Skip-stub. The canonical TrackCard widget plus its 5
          // subcomponents (TrackCardHeader / NextTaskBreadcrumb /
          // TrackStatGrid / LifetimeLearningLine / TrackContinueButton) and
          // the freezed TrackCardViewModel composer are built by Story
          // 26.6 / DNI-388 (Epic 26). When those land, this stub becomes:
          //
          //   for each TrackCardViewModel built from the 4 TrackProgress
          //   variants in the test above, pump it through TrackCard,
          //   capture the widget tree using `tester.allWidgets`, strip
          //   data-bearing nodes (Text, semantics), and assert the
          //   remaining structural Widget-type sequences are identical
          //   across all 4 variants.
          //
          // Matches the DNI-378 / 27.2 skip-stub precedent for
          // StreakReducer which was activated once DNI-337 landed.
        },
        skip:
            'Activated after Story 26.6 / DNI-388 — TrackCardViewModel + '
            '5 canonical subcomponents do not yet exist on dev.',
      );
    },
  );
}
