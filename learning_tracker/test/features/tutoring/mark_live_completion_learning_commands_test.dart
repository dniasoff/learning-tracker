// Story 1.11 (DNI-473) AC-6: `MarkLiveCompletionUseCase` routes the owner
// branch through `LearningCommands.capture`.
// Story 1.24 (DNI-486) AC-1: the tutor branch is rerouted to the tutor
// capture, whose only write is `TutorWriteService.recordLearning` (the
// `tutorRecordLearning` callable); the legacy rejection is deleted.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

import '../../helpers/learner_state/fake_learning_commands.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

Future<CaptureResult> _ownerCapture(LearningCommands commands) =>
    commands.capture(
      curriculumId: 'mishnayos',
      refs: const ['Mishnah Berakhot 1:1'],
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      stage: 1,
    );

void main() {
  late FakeLearningCommands commands;
  late TutorHarness tutor;

  setUp(() {
    commands = FakeLearningCommands();
    tutor = TutorHarness();
  });
  tearDown(() {
    commands.dispose();
    tutor.dispose();
  });

  test('the owner branch delegates to LearningCommands.capture and returns '
      'its result', () async {
    final useCase = MarkLiveCompletionUseCase<CaptureResult>(
      session: ResolvedSession.forOwner(
        selection: const OwnProfileSelection(profileId: 'p1', ownerUid: 'u1'),
        isChildMode: false,
      ),
    );

    final result = await useCase.call(
      () => _ownerCapture(commands),
      tutorWrite: () => _ownerCapture(tutor.commands),
    );

    expect(result, isA<CaptureSuccess>());
    expect((result as CaptureSuccess).eventIds, hasLength(1));
    final call = commands.calls.single;
    expect(call.name, 'capture');
    expect(call.args['source'], LearningEvent.sourceMain);
    expect(call.args['dateState'], DateState.dated);
    expect(tutor.invoker.calls, isEmpty);
  });

  test('the tutor branch records through TutorWriteService.recordLearning '
      '(tutorRecordLearning) and never reaches the owner commands', () async {
    final useCase = MarkLiveCompletionUseCase<CaptureResult>(
      session: ResolvedSession.forTutor(selection: tutor.selection),
    );

    final result = await useCase.call(
      () => _ownerCapture(commands),
      tutorWrite: () => _ownerCapture(tutor.commands),
    );

    expect(result, isA<CaptureSuccess>());
    expect(commands.calls, isEmpty, reason: 'no owner write for a tutor');
    final call = tutor.invoker.calls.single;
    expect(call.fn, 'tutorRecordLearning');
    expect(call.args['grantId'], tutorFixtureGrantId);
    expect(call.args['ownerUid'], tutorFixtureOwnerUid);
    final event = (call.args['events'] as List).single as Map;
    expect(event['fields'], {
      'kind': 'learn',
      'curriculum_id': 'mishnayos',
      'ref': 'Mishnah Berakhot 1:1',
      'source': 'main',
      'date_state': 'dated',
      'learned_on': '2026-10-01',
      'stage': 1,
    });
  });
}
