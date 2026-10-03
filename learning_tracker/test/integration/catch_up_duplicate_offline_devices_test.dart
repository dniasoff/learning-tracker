// DNI-506 (Story 3.3) AC-6: the child and a parent record the same
// catch-up card on two offline devices of one profile. Both event sets are
// kept (NFR-1); the engine counts each leaf once (FR-14), and points follow
// `earningEventIds` (the earliest eligible main event only, AD-50).
//
// Each device runs the real `DefaultLearningCommands` with its writes held
// in the SDK queue (offline); after both sync, the merged log goes through
// the real `LearnerStateEngine`.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

import '../helpers/learner_state/catch_up_card_harness.dart';
import '../helpers/learner_state/catch_up_command_harness.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';

final _rebbe = SubTrack(
  id: ulidB,
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [peah],
  lastChangeId: ulidC,
);

void main() {
  test(
    'both devices\' events are kept; each leaf counts and earns once',
    () async {
      final leaves = [
        mainCatchUpLeaf('Mishnah Berakhot 2:1'),
        mainCatchUpLeaf('Mishnah Berakhot 2:2'),
        subCatchUpLeaf('Mishnah Peah 1:1'),
      ];
      final parent = CatchUpCommandHarness(idSeed: 50000)
        ..port.holdAttempts.add(0);
      final child = CatchUpCommandHarness(
        actor: catchUpChild,
        now: catchUpSunday.add(const Duration(minutes: 5)),
        idSeed: 60000,
      )..port.holdAttempts.add(0);

      final a = await parent.commands.recordCatchUp(catchUpAllAction(leaves));
      final b = await child.commands.recordCatchUp(catchUpAllAction(leaves));
      expect((a as CaptureSuccess).queued, isTrue);
      expect((b as CaptureSuccess).queued, isTrue);

      // Both devices come back online.
      parent.port.release(0);
      child.port.release(0);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final merged = [...parent.written, ...child.written];
      expect(merged, hasLength(6));
      final state = const LearnerStateEngine().run(
        engineInputs(
          events: merged,
          subTracks: [_rebbe],
          settingsHistory: catchUpHistory,
          nowUtc: catchUpSunday.add(const Duration(hours: 2)),
          intents: {
            engineCurriculum: MainTrackIntent(
              curriculumId: engineCurriculum,
              track: MainTrack(
                curriculumId: engineCurriculum,
                state: MainTrackState.active,
              ),
              stages: [engineStage(1)],
            ),
          },
        ),
      );

      // NFR-1: every event of both devices is kept and counted.
      expect(state.countedEventIds, containsAll(merged.map((e) => e.id)));
      // FR-14: distinct leaves count once.
      final c = state[engineCurriculum]!;
      expect(c.distinctLearnt, 3);
      expect(c.learntLeaves, {
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Peah 1:1',
      });
      // AD-50: only the parent's (earlier) main events earn; sub-track
      // events never do.
      final parentMain = [
        for (final e in parent.written)
          if (e.source == LearningEvent.sourceMain) e.id,
      ];
      expect(state.earningEventIds, parentMain.toSet());
      // Both devices attached pts_ entries; the balance filters them.
      expect(parent.port.awards, hasLength(2));
      expect(child.port.awards, hasLength(2));
      // The locked day is a streak day once, whichever device wrote it.
      expect(c.streak!.lastDay, isNotNull);
    },
  );
}
