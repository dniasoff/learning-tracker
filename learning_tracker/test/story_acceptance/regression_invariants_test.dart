/// Invariant test net — 2026-05-17 quality crisis.
///
/// Characterization/invariant tests (N1–N8) documenting the correct system
/// behaviour. Each becomes the regression anchor for a corresponding repair:
///
///   N3 → —   fresh profile reports 0 learnt leaves and a 0 streak per
///            curriculum (baseline)
///   N4 → R3  retired with the completions store (DNI-483)
///   N5 → R4  restoreOrCreate resets activatedAt; lifetime preserved
///   N6 → R5  the learnt count counts distinct leaves (one "done" definition)
///   N7 → F1  pace-goal projected finish anchors to createdAt, not now
///   N8 → C3  retired with the completions store (DNI-483)
///
/// Rule: a failing test is fixed by changing production code only — never by
/// weakening the assertion. Each repair ships as one commit: failing test +
/// fix + green test.
@Tags(['invariants'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart'
    show estimatedFinishDate;
import 'package:test/test.dart';

import '../helpers/fake_clock.dart';
import '../helpers/firestore_fixtures.dart';
import '../helpers/firestore_governed_writer.dart';
import '../helpers/learner_state/engine_fixtures.dart';

void main() {
  group('Invariant net — 2026-05-17 quality crisis', tags: ['invariants'], () {
    // ── N3 — fresh profile = 0 everything ──────────────────────────────────

    group('N3: fresh profile reports 0 learnt leaves and 0 streak', () {
      test('a fresh profile has learnt nothing in every curriculum', () {
        // DNI-483 (R1): progress is LearnerState's distinct learnt leaves,
        // derived from learning_events; the completions store is retired.
        final state = const LearnerStateEngine().run(engineInputs());
        expect(
          state[engineCurriculum]!.distinctLearnt,
          0,
          reason:
              'N3: a profile that has never learnt must report 0 learnt '
              'leaves',
        );
      });

      test('a fresh profile has a zero streak in every curriculum', () {
        // DNI-479 (R6): the streak is the per-curriculum LearnerState
        // streak, derived from learning_events (AD-40); streak_events is
        // retired.
        final state = const LearnerStateEngine().run(engineInputs());
        expect(
          state[engineCurriculum]!.streak,
          const CurriculumStreak(current: 0, best: 0),
          reason:
              'N3: a fresh profile must not manufacture a non-zero streak '
              'from an empty learning-event log',
        );
      });
    });

    // ── N4 — retired with the completions store (DNI-483, R1): archiving a
    // track never touches learning_events, the only record of learning.

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
            writer: FirestoreGovernedWriter(
              firestore,
              uid: uid,
              profileId: profileId,
            ),
          );
          final originalActivatedAt = DateTime.utc(2026, 5, 27, 12);
          await seedTrack(
            firestore,
            uid: uid,
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos,
            activatedAt: originalActivatedAt,
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
        test('the learnt count counts distinct leaves, not stage events', () {
          // DNI-483 (R1): one leaf learnt at two stages is one leaf.
          final state = const LearnerStateEngine().run(
            engineInputs(
              events: [
                engineLearn(1, 'Mishnah Berakhot 1:1', stage: 1, minutes: 1),
                engineLearn(2, 'Mishnah Berakhot 1:1', stage: 2, minutes: 2),
              ],
            ),
          );
          expect(
            state[engineCurriculum]!.distinctLearnt,
            1,
            reason:
                'N6: the learnt count must count distinct leaves, not total '
                'stage events',
          );
        });
      },
    );

    // ── N8 — retired with the completions store (DNI-483, R1): learning is
    // append-only learning_events and unlearn is a `void` event (AD-31).

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
        description: '',
        dateType: 'gregorian',
        goalType: 'pace',
        paceValue: 10,
        pacePeriod: 'per_week',
        createdAt: createdAt,
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
