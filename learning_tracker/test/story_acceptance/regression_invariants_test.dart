/// Invariant test net — 2026-05-17 quality crisis.
///
/// Characterization/invariant tests (N1–N8) documenting the correct system
/// behaviour. Each becomes the regression anchor for a corresponding repair:
///
///   N3 → —   fresh profile reports 0 completions and 0 streak (baseline)
///   N4 → R3  delete+re-add track → completion %, count both 0
///   N5 → R4  restoreOrCreate resets activatedAt; lifetime preserved
///   N6 → R5  completion count and progress % share one "done" definition
///   N7 → F1  pace-goal projected finish anchors to createdAt, not now
///   N8 → C3  purgeHistory never decreases completion documents
///
/// Rule: a failing test is fixed by changing production code only — never by
/// weakening the assertion. Each repair ships as one commit: failing test +
/// fix + green test.
@Tags(['invariants'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart'
    show estimatedFinishDate;
import 'package:test/test.dart';

import '../helpers/fake_clock.dart';
import '../helpers/firestore_fixtures.dart';

void main() {
  group('Invariant net — 2026-05-17 quality crisis', tags: ['invariants'], () {
    // ── N3 — fresh profile = 0 everything ──────────────────────────────────

    group('N3: fresh profile reports 0 completions and 0 streak', () {
      test(
        'getAggregateCountByProfile returns 0 for a profile with no data',
        () async {
          const uid = 'invariant-n3-uid';
          const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
          final firestore = FakeFirebaseFirestore();
          final completions = FirestoreCompletionRepository(
            firestore: firestore,
            uid: uid,
            profileId: profileId,
          );
          final count = await completions.getAggregateCountForCurriculum(
            CurriculumId.mishnayos,
          );
          expect(
            count,
            0,
            reason:
                'N3: a profile that has never marked a completion must '
                'report 0 completions',
          );
        },
      );

      test('streaks table has no row for a fresh profile', () async {
        const uid = 'invariant-n3-streak-uid';
        const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
        final firestore = FakeFirebaseFirestore();
        final eventRepository = FirestoreStreakEventRepository(
          firestore: firestore,
          uid: uid,
          profileId: profileId,
        );
        final container = ProviderContainer(
          overrides: [
            firestoreStreakEventRepositoryProvider.overrideWith(
              (ref) async => eventRepository,
            ),
            streakStateProvider.overrideWith(
              (ref) => StreakStateService(ref: ref),
            ),
          ],
        );
        addTearDown(container.dispose);
        final state = await container.read(streakStateProvider).read();

        expect(
          state.currentStreak,
          0,
          reason:
              'N3: a fresh Firestore profile must not manufacture a non-zero '
              'streak from an empty streak_events collection',
        );
      });
    });

    // ── N4 — delete+re-add: lifetime completions preserved, session starts at 0

    group('N4: delete+re-add track leaves 0 completions', () {
      test(
        'archiving and reactivating preserves lifetime completions but resets the session',
        () async {
          const uid = 'invariant-n4-uid';
          const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
          final firestore = FakeFirebaseFirestore();
          final tracks = FirestoreCurriculumTrackRepository(
            firestore: firestore,
            uid: uid,
            profileId: profileId,
          );
          final completions = FirestoreCompletionRepository(
            firestore: firestore,
            uid: uid,
            profileId: profileId,
          );
          final originalActivatedAt = DateTime.utc(2026, 5, 1);
          await seedTrack(
            firestore,
            uid: uid,
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos,
            activatedAt: originalActivatedAt,
            stateChangedAt: originalActivatedAt,
          );
          // The repository protects the last active curriculum from archival.
          await seedTrack(
            firestore,
            uid: uid,
            profileId: profileId,
            curriculumId: CurriculumId.chumash,
          );
          for (var i = 0; i < 3; i++) {
            await seedCompletion(
              firestore,
              uid: uid,
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'Berakhot 1:${i + 1}',
              completedAt: originalActivatedAt,
            );
          }

          expect(
            await completions.getAggregateCountForCurriculum(
              CurriculumId.mishnayos,
            ),
            3,
          );
          await tracks.archiveTrack(CurriculumId.mishnayos);
          installFakeClock(DateTime.utc(2026, 6, 1, 12));
          final restored = await tracks.activateTrack(CurriculumId.mishnayos);

          expect(
            await completions.getAggregateCountForCurriculum(
              CurriculumId.mishnayos,
            ),
            3,
            reason: 'N4: lifetime completions must survive delete+restore',
          );
          final currentSession =
              (await completions.getCompletionsForCurriculum(
                CurriculumId.mishnayos,
              )).where(
                (completion) =>
                    !completion.completedAt.isBefore(restored.activatedAt),
              );
          expect(
            currentSession,
            isEmpty,
            reason:
                'N4: pre-restore completions must be excluded from the new '
                'current learning session',
          );
        },
      );
    });

    // ── N5 — restoreOrCreate resets activatedAt to mark a new session ────────

    group(
      'N5: restoreOrCreate resets activatedAt for a new learning session',
      () {
        test('reactivated curriculum track gets activatedAt = now', () async {
          const uid = 'invariant-n5-uid';
          const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
          final firestore = FakeFirebaseFirestore();
          final tracks = FirestoreCurriculumTrackRepository(
            firestore: firestore,
            uid: uid,
            profileId: profileId,
          );
          final originalActivatedAt = DateTime.utc(2026, 5, 27, 12);
          await seedTrack(
            firestore,
            uid: uid,
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos,
            activatedAt: originalActivatedAt,
            stateChangedAt: originalActivatedAt,
          );
          await seedTrack(
            firestore,
            uid: uid,
            profileId: profileId,
            curriculumId: CurriculumId.chumash,
          );
          await tracks.archiveTrack(CurriculumId.mishnayos);

          final fixedNow = DateTime.utc(2026, 6, 1, 12);
          installFakeClock(fixedNow);
          final restored = await tracks.activateTrack(CurriculumId.mishnayos);

          expect(
            restored.activatedAt,
            fixedNow,
            reason:
                'N5: reactivation must reset activatedAt so the current '
                'learning session starts fresh',
          );
        });
      },
    );

    // ── N6 — completion count and progress % share one "done" definition ────

    group(
      'N6: completion count and lifetime % agree on one definition of done',
      () {
        test(
          'aggregate count counts distinct completed refs, not total rows',
          () async {
            const uid = 'invariant-n6-uid';
            const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
            final firestore = FakeFirebaseFirestore();
            final completions = FirestoreCompletionRepository(
              firestore: firestore,
              uid: uid,
              profileId: profileId,
            );
            await seedCompletion(
              firestore,
              uid: uid,
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'Berakhot 1:1',
              stageId: 1,
              completedAt: DateTime.utc(2026, 5, 1),
            );
            await seedCompletion(
              firestore,
              uid: uid,
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'Berakhot 1:1',
              stageId: 2,
              completedAt: DateTime.utc(2026, 5, 2),
            );

            expect(
              await completions.getAggregateCountForCurriculum(
                CurriculumId.mishnayos,
              ),
              1,
              reason:
                  'N6: the Firestore aggregate must count distinct completed '
                  'sefariaRefs, not total stage rows',
            );
          },
        );
      },
    );

    // ── N8 — purgeHistory never decreases completion_events row count (C3) ───

    group('N8: purgeHistory never decreases completion_events row count', () {
      test(
        'purging completions stamps purgedAt and keeps document count stable',
        () async {
          const uid = 'invariant-n8-uid';
          const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
          final firestore = FakeFirebaseFirestore();
          final completions = FirestoreCompletionRepository(
            firestore: firestore,
            uid: uid,
            profileId: profileId,
          );
          final completedAt = DateTime.utc(2026, 5, 1);
          for (var i = 1; i <= 4; i++) {
            await seedCompletion(
              firestore,
              uid: uid,
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'Berakhot $i:1',
              completedAt: completedAt,
            );
          }

          final collection = firestore
              .collection('users')
              .doc(uid)
              .collection('learner_profiles')
              .doc(profileId)
              .collection('completions');
          final countBefore = (await collection.get()).docs.length;
          for (var i = 1; i <= 4; i++) {
            await completions.purgeCompletion(
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'Berakhot $i:1',
              stageId: 1,
              purgedAt: DateTime.utc(2026, 6, 1),
            );
          }

          expect((await collection.get()).docs, hasLength(countBefore));
          expect(
            await completions.getCompletionsForCurriculum(
              CurriculumId.mishnayos,
            ),
            isEmpty,
            reason:
                'N8: purged completion tombstones remain stored but are '
                'hidden from active completion reads',
          );
        },
      );
    });

    // ── N7 — pace-goal projected finish anchors to createdAt, not now ────────

    group('N7: pace-goal projected finish anchors to createdAt, not now', () {
      // AUD-t-story-acceptance-02: this test now calls the REAL production
      // formula (estimatedFinishDate, extracted from
      // _TrackDetailScreenState._estimatedFinish in track_detail_screen.dart)
      // instead of re-typing its date math inline. The original version built
      // two independent copies of the same formula and asserted they agreed
      // with each other — it could never fail no matter what production code
      // did, so a regression that re-anchored the projection to "now" would
      // ship undetected. Verified manually: temporarily reverting
      // estimatedFinishDate()'s anchor to DateTimeFactory.nowLocal() (the F1
      // bug shape) makes this test fail red; anchoring to goal.createdAt
      // makes it pass.
      GoalEntity paceGoal({required DateTime createdAt}) => GoalEntity(
        id: 1,
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        description: '',
        dateType: 'gregorian',
        goalType: 'pace',
        paceValue: 10,
        pacePeriod: 'per_week',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      test(
        'projected finish uses goal.createdAt as anchor — stable across days',
        () {
          final createdAt = DateTime.now().subtract(const Duration(days: 7));
          final goal = paceGoal(createdAt: createdAt);

          const totalItems = 100;
          const completedItems = 0;
          const itemsRemaining = totalItems - completedItems; // 100

          final projected1 = estimatedFinishDate(
            goal: goal,
            remainingInPaceUnit: itemsRemaining,
          );
          final projected2 = estimatedFinishDate(
            goal: goal,
            remainingInPaceUnit: itemsRemaining,
          );

          expect(
            projected1,
            isNotNull,
            reason:
                'N7: a pace goal with positive remaining scope must '
                'produce a projected finish date',
          );
          expect(
            projected1,
            equals(createdAt.add(const Duration(days: 70))),
            reason:
                'N7: projected finish must be createdAt + 70 days for '
                '100 items at 10/week',
          );

          final nowBased = DateTime.now().add(const Duration(days: 70));
          final differenceMillis =
              (projected1!.millisecondsSinceEpoch -
                      nowBased.millisecondsSinceEpoch)
                  .abs();
          expect(
            differenceMillis,
            greaterThan(
              const Duration(days: 6, hours: 23, minutes: 50).inMilliseconds,
            ),
            reason:
                'N7: createdAt-anchored projection must differ from '
                'now-anchored projection by approximately 7 days',
          );

          expect(
            projected1,
            equals(projected2),
            reason:
                'N7: computing the projected finish twice must yield the '
                'exact same instant — createdAt is fixed, so there is no '
                'drift from calling estimatedFinishDate() again',
          );
        },
      );
    });
  });
}
