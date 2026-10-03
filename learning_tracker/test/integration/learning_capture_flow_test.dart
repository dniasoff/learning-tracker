// Story 1.11 (DNI-473) AC-1 / AC-4 / AC-5 integration: the main-track
// reader's Mark complete, end to end through the real
// `DefaultLearningCommands` over an in-memory write port.
//
// The daily task list is the planner's (unchanged by this story): the same
// tasks in the same order, one tap completes the current one and moves on
// to the next. The tap writes exactly one learn event with its pts_ entry
// (AD-50) and never touches the legacy completion writer.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../e2e/fakes/e2e_fakes.dart' show FakeCompletionRepository;
import '../helpers/learner_state/c0_fixtures.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state/fake_learning_commands.dart';
import '../helpers/learner_state/in_memory_ports.dart';
import '../helpers/pump_app.dart';
import '../helpers/tutoring/tutor_learning_harness.dart';

const _ref1 = 'Mishnah Berakhot 1:1';
const _ref2 = 'Mishnah Berakhot 1:2';

/// Tuesday 2026-09-01 10:00Z (unlocked for the UTC fixture learner).
final _tuesday = engineAt(600);

/// Saturday 2026-09-05 10:00Z (inside the fixture Shabbos lock).
final _shabbos = DateTime.utc(2026, 9, 5, 10);

DailyTask _task(String ref) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Test Track',
  estimatedEffortMinutes: 5,
);

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _NoGoals extends Fake implements GoalRepository {
  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async => [];
}

class _FontSize extends FontSizeNotifier {
  @override
  // ignore: prefer_const_declarations
  FontSize build() => FontSize.medium;
}

class _Nikud extends ShowNikud {
  @override
  bool build() => true;
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _NoTutor extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

/// Reads whose event log is everything the port has committed (as the SDK
/// cache would show it).
final class _PortBackedReads implements LearningCommandReads {
  _PortBackedReads(this._port);

  final InMemoryLearningWritePort _port;
  final _inner = FakeLearningCommandReads(
    history: c0SettingsHistory(),
    corpora: {engineCurriculum: mishnayosCorpus()},
  );

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) =>
      _inner.settingsHistory(scope);

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) async => [
    for (final c in _port.chunks) ...c.events,
  ];

  @override
  Future<Corpus?> corpus(String curriculumId) => _inner.corpus(curriculumId);

  @override
  Future<int> pointsAmount(LearnerScope s, String curriculumId, int? stage) =>
      _inner.pointsAmount(s, curriculumId, stage);
}

final class _Flow {
  _Flow({DateTime? now}) {
    final at = now ?? _tuesday;
    var seq = 40000;
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: _PortBackedReads(port),
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => at,
      newUlid: (_) => engineUlid(seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
    when(() => router.replace(any())).thenAnswer((_) async => null);
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/reader');
  }

  final port = InMemoryLearningWritePort();
  late final DefaultLearningCommands commands;
  final legacy = FakeCompletionRepository();
  final router = _MockStackRouter();

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  List<PointsAward> get awards => [for (final c in port.chunks) ...c.awards];

  /// [tutor] runs the reader in that harness's tutored session: its
  /// commands are the talmid's tutor callables (DNI-486).
  Widget app({TutorHarness? tutor}) {
    final index = ContentIndex.fromCurricula({
      CurriculumId.mishnayos: [
        for (final (i, ref) in [_ref1, _ref2].indexed)
          ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Berakhot',
            level4: '${i + 1}',
            displayNameHe: ref,
            displayNameEn: ref,
            sefariaRef: ref,
            sortOrder: i,
            isLeaf: true,
          ),
      ],
    });
    final overrides = <Override>[
      textContentProvider(_ref1).overrideWith(
        (ref) => Future.value(
          TextContent.single(
            sefariaRef: _ref1,
            hebrewText: 'מֵאֵימָתַי קוֹרִין',
            englishText: 'From when may one recite',
          ),
        ),
      ),
      fontSizeProvider.overrideWith(_FontSize.new),
      showNikudProvider.overrideWith(_Nikud.new),
      renderedDisplayForRefProvider(_ref1).overrideWith((ref) async => _ref1),
      contentIndexProvider.overrideWith((ref) async => index),
      useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
      if (tutor == null)
        activeTutoredProfileSelectionProvider.overrideWith(_NoTutor.new)
      else ...[
        ...tutoredOverrides(selection: tutor.selection),
        tutorLearningCommandsProvider.overrideWith(
          (ref) async => tutor.commands,
        ),
      ],
      allDailyTasksProvider.overrideWith(
        (ref) => Future.value([_task(_ref1), _task(_ref2)]),
      ),
      trackStorageKeyForTrackIdProvider.overrideWith(
        (ref, trackId) async => 'personal',
      ),
      completionRepositoryProvider.overrideWithValue(legacy),
      goalRepositoryProvider.overrideWithValue(_NoGoals()),
      analyticsServiceProvider.overrideWithValue(const NullAnalyticsService()),
      learningCommandsProvider.overrideWith((ref) async => commands),
    ];
    return pumpApp(
      overrides: overrides,
      child: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const MediaQuery(
          data: MediaQueryData(size: Size(800, 1200)),
          child: TextDisplayScreen(sefariaRef: _ref1),
        ),
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(_FakePageRouteInfo());
  });

  testWidgets('AC-1: one tap on the current task is one capture — one '
      'learn event with its pts_ entry, no legacy write — and the reader '
      'moves on to the next task in order', (tester) async {
    final flow = _Flow();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    expect(find.text('Mark complete'), findsOneWidget);
    await tester.tap(find.text('Mark complete'));
    await _settle(tester);

    final event = flow.written.single;
    expect(event.ref, _ref1);
    expect(event.source, LearningEvent.sourceMain);
    expect(event.dateState, DateState.dated);
    expect(event.learnedOn, '2026-09-01');
    expect(event.stage, 1);
    expect(flow.awards.single.eventId, event.id, reason: 'AD-50 pts_');
    expect(flow.legacy.markedRequests, isEmpty, reason: 'no legacy writer');

    final route =
        verify(() => flow.router.replace(captureAny())).captured.single
            as TextDisplayRoute;
    expect(route.args?.sefariaRef, _ref2, reason: 'same order: next task');
  });

  testWidgets('DNI-486: a tutor live capture is the callable alone — no '
      'bookmark write — and the reader still moves on', (tester) async {
    final flow = _Flow();
    final tutor = TutorHarness();
    addTearDown(flow.commands.dispose);
    addTearDown(tutor.dispose);
    await tester.pumpWidget(flow.app(tutor: tutor));
    await _settle(tester);

    await tester.tap(find.text('Mark complete'));
    await _settle(tester);

    expect(tutor.invoker.calls.single.fn, 'tutorRecordLearning');
    expect(flow.port.attempts, isEmpty, reason: 'no owner-path write');
    expect(
      flow.bookmarks.advanced,
      isEmpty,
      reason: 'the bookmark is owner-only: a tutor never writes it',
    );
    final route =
        verify(() => flow.router.replace(captureAny())).captured.single
            as TextDisplayRoute;
    expect(route.args?.sefariaRef, _ref2);
  });

  testWidgets('AC-4: Undo after a main-task completion voids exactly that '
      'event', (tester) async {
    final flow = _Flow();
    addTearDown(flow.commands.dispose);
    when(() => flow.router.replace(any())).thenAnswer((_) async => null);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(find.text('Mark complete'));
    await _settle(tester);
    final learnt = flow.written.single;
    expect(find.text('Marked complete'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    final voids = flow.written.where((e) => e.isVoid).toList();
    expect(voids.single.targetId, learnt.id);
  });

  testWidgets('AC-5: during a lock the tap writes nothing and says so', (
    tester,
  ) async {
    final flow = _Flow(now: _shabbos);
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(find.text('Mark complete'));
    await _settle(tester);
    expect(flow.port.attempts, isEmpty);
    expect(
      find.text('Not recorded — the app is closed for Shabbos and Yom Tov.'),
      findsOneWidget,
    );
    verifyNever(() => flow.router.replace(any()));
  });

  testWidgets('AC-5: a permanent rejection says not saved with Retry; Retry '
      're-sends the same event', (tester) async {
    final flow = _Flow();
    addTearDown(flow.commands.dispose);
    flow.port.failNextWith(const PermanentWriteRejection('permission-denied'));
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(find.text('Mark complete'));
    await _settle(tester);
    expect(flow.written, isEmpty);
    final attempted = flow.port.attempts.single.events.single;
    expect(
      find.text('Not saved — your learning was not recorded.'),
      findsOneWidget,
    );
    expect(find.text('Mark complete'), findsOneWidget, reason: 'not done');

    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(flow.written.single.id, attempted.id, reason: 'same ULID');
  });
}
