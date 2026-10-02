// Story 2.10 (DNI-501) AC-3 / AC-5 unit: the events and points entries an
// Up to… capture produces. The picker builds no payloads itself; it hands
// the included leaves to `LearningCommands.capture` (Story 1.7), so these
// cases pin that contract for the two Up to… sources.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state_fixtures.dart';
import '../helpers/capture_harness.dart';
import '../helpers/up_to_fixtures.dart';

const _run = ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:3'];

void main() {
  test('sub-track: one dated learn per included leaf, source = the '
      'sub-track ULID, no stage, no pts_', () async {
    final rig = CaptureRig(now: engineAt(1200));
    addTearDown(rig.dispose);
    await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: _run,
      source: schoolId,
      dateState: DateState.dated,
    );
    expect([for (final e in rig.written) e.ref], _run);
    for (final e in rig.written) {
      expect(e.isLearn, isTrue);
      expect(e.source, schoolId);
      expect(e.dateState, DateState.dated);
      expect(e.stage, isNull);
      expect(e.toStorage().containsKey('stage'), isFalse);
    }
    expect(rig.awards, isEmpty);
  });

  test('main: stage = first stage order, each event with its pts_ entry '
      'created at its recorded_at', () async {
    final rig = CaptureRig(now: engineAt(1200));
    addTearDown(rig.dispose);
    await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: _run,
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      stage: 1,
    );
    expect([for (final e in rig.written) e.stage], [1, 1]);
    expect(
      [for (final a in rig.awards) a.eventId],
      [for (final e in rig.written) e.id],
    );
    for (final a in rig.awards) {
      expect(a.amount, greaterThan(0));
      expect(a.createdAt, engineAt(1200));
    }
  });

  test('learned_on is the civil today in the learner\'s time zone, not '
      'UTC', () async {
    // 2026-09-02T02:00Z is still 2026-09-01 in New York.
    final rig = CaptureRig(
      now: DateTime.utc(2026, 9, 2, 2),
      settings: LearnerSettingsHistory.constant(
        const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'America/New_York',
        ),
      ),
    );
    addTearDown(rig.dispose);
    final result = await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: _run,
      source: schoolId,
      dateState: DateState.dated,
    );
    expect(result, isA<CaptureSuccess>());
    expect({for (final e in rig.written) e.learnedOn}, {'2026-09-01'});
  });

  test('client event ids are fixed before the write and reused on '
      'retry', () async {
    final rig = CaptureRig(now: engineAt(1200));
    addTearDown(rig.dispose);
    rig.port.failNextWith(const PermanentWriteRejection('unavailable'));
    final first = await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: _run,
      source: schoolId,
      dateState: DateState.dated,
    );
    expect(first, isA<CaptureRejected>());
    final attempted = [for (final e in rig.port.attempts.single.events) e.id];
    final failure = (await rig.commands.watchPendingFailures().first).single;
    expect(failure.eventIds, attempted);
    final retried = await rig.commands.retry(failure.id);
    expect(retried, isA<CaptureSuccess>());
    expect([for (final e in rig.written) e.id], attempted);
  });
}
