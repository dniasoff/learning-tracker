// Story 1.11 (DNI-473) AC-6: `MarkLiveCompletionUseCase` routes the owner
// branch through `LearningCommands.capture`; the tutor branch is unchanged
// (it still rejects with `TutorWriteForbiddenException`, logs
// `tutor_live_mark_blocked` and never reaches the commands) until the
// tutor-capture story reroutes it to `TutorWriteService`.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

import '../../helpers/learner_state/fake_learning_commands.dart';

final class _RecordingAnalytics extends NullAnalyticsService {
  final events = <String>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async => events.add(name);
}

Future<CaptureResult> _ownerCapture(FakeLearningCommands commands) =>
    commands.capture(
      curriculumId: 'mishnayos',
      refs: const ['Mishnah Berakhot 1:1'],
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      stage: 1,
    );

void main() {
  late FakeLearningCommands commands;
  late _RecordingAnalytics analytics;

  setUp(() {
    commands = FakeLearningCommands();
    analytics = _RecordingAnalytics();
  });
  tearDown(() => commands.dispose());

  test('the owner branch delegates to LearningCommands.capture and returns '
      'its result', () async {
    final useCase = MarkLiveCompletionUseCase<CaptureResult>(
      session: ResolvedSession.forOwner(
        selection: const OwnProfileSelection(profileId: 'p1', ownerUid: 'u1'),
        isChildMode: false,
      ),
      analytics: analytics,
    );

    final result = await useCase.call(() => _ownerCapture(commands));

    expect(result, isA<CaptureSuccess>());
    expect((result as CaptureSuccess).eventIds, hasLength(1));
    final call = commands.calls.single;
    expect(call.name, 'capture');
    expect(call.args['source'], LearningEvent.sourceMain);
    expect(call.args['dateState'], DateState.dated);
    expect(analytics.events, isEmpty);
  });

  test('the tutor branch is unchanged: it throws TutorWriteForbidden, logs '
      'tutor_live_mark_blocked and never calls the commands', () async {
    final useCase = MarkLiveCompletionUseCase<CaptureResult>(
      session: ResolvedSession.forTutor(
        selection: const TutoredProfileSelection(
          profileId: 'p1',
          ownerUid: 'u1',
          grantId: 'g1',
          permissions: TutorPermissions(),
        ),
      ),
      analytics: analytics,
    );

    await expectLater(
      useCase.call(() => _ownerCapture(commands)),
      throwsA(isA<TutorWriteForbiddenException>()),
    );
    expect(commands.calls, isEmpty, reason: 'no tutor path on the commands');
    expect(analytics.events, [AnalyticsEvent.tutorLiveMarkBlocked]);
  });
}
