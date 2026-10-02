/// Story acceptance coverage for bulk prior marking.
///
/// Story 1.11 (DNI-473, R10/R15 port): a bulk prior mark is a
/// `before_tracking` learning event — no `learned_on`, no pts_ entry and no
/// streak day — written through the real `DefaultLearningCommands`.
@Tags(['epic_27', 'story_27_5'])
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:test/test.dart';

import '../helpers/learner_state/c0_fixtures.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state/fake_learning_commands.dart';
import '../helpers/learner_state/in_memory_ports.dart';

void main() {
  group('Story 27.5 — bulk prior completions', tags: ['story_27_5'], () {
    test('a bulk prior mark credits neither streak nor points', () async {
      final port = InMemoryLearningWritePort();
      var seq = 70000;
      final commands = DefaultLearningCommands(
        scope: c0Scope(),
        actor: const Actor(
          uid: 'owner-uid',
          role: ActorRole.parent,
          displayName: '',
        ),
        reads: FakeLearningCommandReads(history: c0SettingsHistory()),
        writePort: port,
        gate: const LockWindowCaptureGate(),
        analytics: RecordingLearningAnalytics(),
        failureReporter: RecordingLearningFailureReporter(),
        clock: () => engineAt(600),
        newUlid: (_) => engineUlid(seq++),
        ackWait: const Duration(milliseconds: 40),
        pointsWait: const Duration(milliseconds: 40),
      );
      addTearDown(commands.dispose);

      final result = await commands.capture(
        curriculumId: engineCurriculum,
        nodes: const [berakhot],
        source: LearningEvent.sourceMain,
        dateState: DateState.beforeTracking,
      );

      expect(result, isA<CaptureSuccess>());
      final event = port.chunks.single.events.single;
      expect(event.dateState, DateState.beforeTracking);
      expect(event.learnedOn, isNull);
      expect(event.level, berakhot.level);
      expect(port.chunks.single.awards, isEmpty, reason: 'no points');
      expect(
        streakDay(
          event,
          settingsHistory: c0SettingsHistory(),
          locks: const <LockWindow>[],
        ),
        isNull,
        reason: 'no streak day',
      );
    });
  });
}
