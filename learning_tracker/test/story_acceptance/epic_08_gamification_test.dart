/// Story acceptance tests for Epic 8 -- Gamification.
@Tags(['epic_8'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_log.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_feedback_controller.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedCompletion;
import '../helpers/test_database.dart';

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 0,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.now(),
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  // ── Story 8.1: Points system ──────────────────────────────────

  group('Story 8.1 -- Points system', tags: ['story_8_1'], () {
    late UserDatabase db;
    late int trackId;
    late PointsService pointsService;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
      final now = DateTime.now();
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              trackId: trackId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      pointsService = PointsService(db, profileId: 1);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertCompletion({
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required int points,
      String trackType = 'personal',
    }) async {
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          trackId: Value(trackId),
          eventTimestamp: DateTime.now(),
          points: Value(points),
        ),
      );
    }

    test('completing a content item awards points', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );

      final total = await pointsService.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(total, 10);
    });

    test('points vary by stage (later stages worth more)', () async {
      // Default: Learn=10, Chazara1=5, Chazara2=3
      final learn = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
        trackId: trackId,
      );
      final chazara1 = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 2,
        trackId: trackId,
      );
      final chazara2 = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 3,
        trackId: trackId,
      );

      expect(learn, 10);
      expect(chazara1, 5);
      expect(chazara2, 3);
    });

    test('total points aggregated across all curricula', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.bavli.storageKey,
        sefariaRef: 'Berakhot 2a',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.2',
        stageId: 1,
        points: 10,
      );

      // Per-curriculum
      final mishnayosTotal = await pointsService.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(mishnayosTotal, 20);

      final bavliTotal = await pointsService.getCurriculumTotal(
        CurriculumId.bavli.storageKey,
      );
      expect(bavliTotal, 10);

      // Global (derived sum — raw completion events, not the debitable balance)
      final globalTotal = await pointsService.getDerivedTotal();
      expect(globalTotal, 30);
    });
  });

  // ── Story 8.2: Global Streak Tracking ────────────────────────

  group('Story 8.2 -- Global Streak Tracking', tags: ['story_8_2'], () {
    late UserDatabase db;
    late int trackId;
    late StreakService streakService;
    late StreakEventLog log;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
      streakService = StreakService(db, profileId: 1);
      log = StreakEventLog(db);
    });

    tearDown(() async {
      await db.close();
    });

    // Streak state is derived from `streak_events` by `core/streak/`
    // (post-DNI-337). Old `StreakService.recordCompletion` semantics
    // (incl. grace period) are gone; the reducer is UTC-day only.
    Future<void> recordOn(DateTime utc) => log.append(
      StreakEvent(profileId: 1, eventType: 'completion', eventTimestamp: utc),
    );

    test('three consecutive UTC days → streak=3 (no grace)', () async {
      await recordOn(DateTimeFactory.utc(2026, 3, 10, 12));
      await recordOn(DateTimeFactory.utc(2026, 3, 11, 14));
      await recordOn(DateTimeFactory.utc(2026, 3, 12, 9));

      final state = await StreakStateProvider(
        db: db,
        clock: FakeLocalDayClock(DateTimeFactory.utc(2026, 3, 12, 15)),
      ).read(profileId: 1);
      expect(state.currentStreak, 3);
      expect(state.maxStreak, 3);
    });

    test('streak does not double-increment on same UTC day', () async {
      await recordOn(DateTimeFactory.utc(2026, 3, 10, 8));
      await recordOn(DateTimeFactory.utc(2026, 3, 10, 20));

      final state = await StreakStateProvider(
        db: db,
        clock: FakeLocalDayClock(DateTimeFactory.utc(2026, 3, 10, 22)),
      ).read(profileId: 1);
      expect(state.currentStreak, 1);
    });

    test('streak calendar returns active dates for range', () async {
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'test',
          sefariaRef: 'Genesis.1',
          stageId: 1,
          trackType: 'primary',
          trackId: Value(trackId),
          eventTimestamp: DateTimeFactory.utc(2026, 3, 10, 12),
        ),
      );
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'test',
          sefariaRef: 'Genesis.2',
          stageId: 1,
          trackType: 'primary',
          trackId: Value(trackId),
          eventTimestamp: DateTimeFactory.utc(2026, 3, 12, 12),
        ),
      );

      final calendar = await streakService.getStreakCalendar(
        startUtc: DateTimeFactory.utc(2026, 3, 9),
        endUtc: DateTimeFactory.utc(2026, 3, 13),
      );
      expect(calendar.length, 2);
    });
  });

  // ── Story 8.4: Completion Feedback & Animations (Unit) ────────

  group(
    'Story 8.4 -- Completion Feedback & Animations',
    tags: ['story_8_4'],
    () {
      group('CompletionFeedbackController', () {
        late CompletionFeedbackController controller;

        setUp(() {
          controller = CompletionFeedbackController();
        });

        tearDown(() {
          controller.dispose();
        });

        test('starts idle, becomes active on start()', () {
          expect(controller.phase, CompletionFeedbackPhase.idle);
          expect(controller.isActive, false);

          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: ProfileMode.child,
            ),
          );

          expect(controller.phase, CompletionFeedbackPhase.checkmark);
          expect(controller.isActive, true);
        });

        test('child mode: checkmark → pointsPopup → progressFill → idle', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: ProfileMode.child,
            ),
          );

          expect(controller.phase, CompletionFeedbackPhase.checkmark);
          controller.advance();
          expect(controller.phase, CompletionFeedbackPhase.pointsPopup);
          controller.advance();
          expect(controller.phase, CompletionFeedbackPhase.progressFill);
          controller.advance();
          expect(controller.phase, CompletionFeedbackPhase.idle);
          expect(controller.isActive, false);
        });

        test(
          'adult mode: checkmark → progressFill → idle (skips points popup)',
          () {
            controller.start(
              const CompletionFeedbackData(
                pointsAwarded: 10,
                progressBefore: 0.5,
                progressAfter: 0.6,
                userMode: ProfileMode.adult,
              ),
            );

            expect(controller.phase, CompletionFeedbackPhase.checkmark);
            controller.advance();
            expect(controller.phase, CompletionFeedbackPhase.progressFill);
            controller.advance();
            expect(controller.phase, CompletionFeedbackPhase.idle);
          },
        );

        test('streak increment adds streakBump phase', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              streakBefore: 2,
              streakAfter: 3,
              userMode: ProfileMode.child,
            ),
          );

          controller.advance(); // → pointsPopup
          controller.advance(); // → progressFill
          controller.advance(); // → streakBump
          expect(controller.phase, CompletionFeedbackPhase.streakBump);
          controller.advance(); // → idle
          expect(controller.phase, CompletionFeedbackPhase.idle);
        });

        test('cancel() immediately returns to idle', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: ProfileMode.child,
            ),
          );

          expect(controller.isActive, true);
          controller.cancel();
          expect(controller.phase, CompletionFeedbackPhase.idle);
          expect(controller.isActive, false);
          // Drift's isNull conflicts with matcher's isNull — use direct check
          expect(controller.data == null, true);
        });

        test('points popup displays correct point value from data', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 25,
              progressBefore: 0.3,
              progressAfter: 0.4,
              userMode: ProfileMode.child,
            ),
          );

          expect(controller.data!.pointsAwarded, 25);
        });

        test('notifies listeners on phase transitions', () {
          var notifyCount = 0;
          controller.addListener(() => notifyCount++);

          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0,
              progressAfter: 0.1,
              userMode: ProfileMode.child,
            ),
          );
          expect(notifyCount, 1);

          controller.advance();
          expect(notifyCount, 2);
        });
      });

      group('Integration: completion feedback sequence', () {
        test(
          'child mode full sequence: checkmark → points → progress → streak',
          () {
            final controller = CompletionFeedbackController();

            controller.start(
              const CompletionFeedbackData(
                pointsAwarded: 10,
                progressBefore: 0.5,
                progressAfter: 0.6,
                streakBefore: 2,
                streakAfter: 3,
                userMode: ProfileMode.child,
              ),
            );

            final phases = <CompletionFeedbackPhase>[controller.phase];
            while (controller.isActive) {
              controller.advance();
              phases.add(controller.phase);
            }

            expect(phases, [
              CompletionFeedbackPhase.checkmark,
              CompletionFeedbackPhase.pointsPopup,
              CompletionFeedbackPhase.progressFill,
              CompletionFeedbackPhase.streakBump,
              CompletionFeedbackPhase.idle,
            ]);

            controller.dispose();
          },
        );

        test('adult mode sequence: checkmark → progress → idle', () {
          final controller = CompletionFeedbackController();

          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: ProfileMode.adult,
            ),
          );

          final phases = <CompletionFeedbackPhase>[controller.phase];
          while (controller.isActive) {
            controller.advance();
            phases.add(controller.phase);
          }

          expect(phases, [
            CompletionFeedbackPhase.checkmark,
            CompletionFeedbackPhase.progressFill,
            CompletionFeedbackPhase.idle,
          ]);

          controller.dispose();
        });
      });
    },
  );
}
