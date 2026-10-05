// DNI-486 capture and governed-write checks use the device user's Sacred
// Time settings while a tutor is viewing a talmid (product ruling 2026-10-05).

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';

import '../../helpers/learner_state_fixtures.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 8),
  DateTime.utc(2026, 10, 2, 20),
);

final _talmidHistory = LearnerSettingsHistory.constant(
  const LearnerSettings(profileId: profileUlid, timeZone: 'Asia/Jerusalem'),
);
final _tutorHistory = LearnerSettingsHistory.constant(
  const LearnerSettings(profileId: 'tutor-profile', timeZone: 'Europe/London'),
);

final class _HistoryOnlyGate implements CaptureGate {
  const _HistoryOnlyGate(this.history);

  final LearnerSettingsHistory history;

  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) =>
      identical(settingsHistory, history) && _lock.contains(nowUtc)
      ? GateLocked(_lock)
      : const GateOpen();
}

void main() {
  group("tutor captures follow the device user's lock", () {
    test(
      'the talmid lock does not stop capture when the tutor is unlocked',
      () async {
        final h = TutorHarness(
          gate: _HistoryOnlyGate(_talmidHistory),
          history: _talmidHistory,
          lockHistories: const [],
        );
        addTearDown(h.dispose);

        final result = await h.commands.capture(
          curriculumId: 'mishnayos',
          refs: const ['Mishnah Berakhot 2:1'],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
        );

        expect(result, isA<CaptureSuccess>());
        expect(h.invoker.calls, hasLength(1));
      },
    );

    test(
      'the tutor lock stops capture even when the talmid is unlocked',
      () async {
        final h = TutorHarness(
          gate: _HistoryOnlyGate(_tutorHistory),
          history: _talmidHistory,
          lockHistories: [_tutorHistory],
        );
        addTearDown(h.dispose);

        final result = await h.commands.capture(
          curriculumId: 'mishnayos',
          refs: const ['Mishnah Berakhot 2:1'],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
        );

        expect(result, CaptureResult.locked(_lock));
        expect(h.invoker.calls, isEmpty);
      },
    );

    test('a governed write uses the same tutor-owned lock', () async {
      final h = TutorHarness(
        gate: _HistoryOnlyGate(_tutorHistory),
        history: _talmidHistory,
        lockHistories: [_tutorHistory],
      );
      addTearDown(h.dispose);

      await expectLater(
        h.governed.upsertGoal(goalId: 'g1', data: const {'description': 'x'}),
        throwsA(
          isA<TutorGovernedWriteException>().having(
            (e) => e.refusal,
            'refusal',
            isA<TutorPreflightLocked>(),
          ),
        ),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });
}
