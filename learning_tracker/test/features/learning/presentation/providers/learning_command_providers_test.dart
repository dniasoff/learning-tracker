// Mirror test for
// `lib/features/learning/presentation/providers/learning_command_providers.dart`
// (C0 DNI-524 AC-5; DNI-469 T7 wiring).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/learner_state_fixtures.dart';

final class _FixedPoints implements PointsAmountReader {
  @override
  Future<int> pointsAmount(LearnerScope s, String c, int? stage) async => 7;
}

final class _RecordingCrashlytics implements CrashlyticsService {
  final errors = <(Object, bool)>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async => errors.add((error, fatal));

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserIdentifier(String? profileId) async {}
}

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: profileUlid,
  displayName: 'Dovi',
  mode: mode,
  createdAt: t2,
  updatedAt: t2,
);

void main() {
  test('captureGateProvider is the real LockWindowCaptureGate', () {
    final container = ProviderContainer.test();
    expect(container.read(captureGateProvider), isA<LockWindowCaptureGate>());
  });

  test('learningAnalyticsProvider logs the catalogued capture event', () async {
    final analytics = FakeAnalyticsService();
    final container = ProviderContainer.test(
      overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
    );
    container
        .read(learningAnalyticsProvider)
        .capture(
          curriculumId: 'mishnayos',
          sourceKind: CaptureSourceKind.main,
          dateState: DateState.dated,
          count: 2,
        );
    await pumpEventQueue();
    expect(analytics.eventNames, [AnalyticsEvent.capture]);
    expect(analytics.lastParamsOf(AnalyticsEvent.capture), {
      'curriculum_id': 'mishnayos',
      'source_kind': 'main',
      'date_state': 'dated',
      'count': 2,
    });
  });

  test('the failure reporter records an enum-only non-fatal', () async {
    final crashlytics = _RecordingCrashlytics();
    final container = ProviderContainer.test(
      overrides: [crashlyticsServiceProvider.overrideWithValue(crashlytics)],
    );
    container
        .read(learningFailureReporterProvider)
        .writeRejected(
          command: LearningCommandKind.capture,
          reason: PendingFailureReason.permissionDenied,
          writeCount: 2,
        );
    await pumpEventQueue();
    final (error, fatal) = crashlytics.errors.single;
    expect(fatal, isFalse);
    expect(
      error,
      isA<LearningWriteRejectedError>()
          .having((e) => e.command, 'command', LearningCommandKind.capture)
          .having((e) => e.writeCount, 'writeCount', 2),
    );
  });

  group('learningSessionActor', () {
    test('a child profile without a verified parent PIN acts as child', () {
      final actor = learningSessionActor(
        uid: 'auth-uid',
        profile: _profile(ProfileMode.child),
        pinProfileId: null,
      );
      expect(
        actor,
        const Actor(
          uid: 'auth-uid',
          role: ActorRole.child,
          displayName: 'Dovi',
        ),
      );
    });

    test('a verified parent PIN or an adult profile acts as parent', () {
      for (final (profile, pin) in [
        (_profile(ProfileMode.child), profileUlid),
        (_profile(ProfileMode.adult), null),
        (null, null),
      ]) {
        final actor = learningSessionActor(
          uid: 'auth-uid',
          profile: profile,
          pinProfileId: pin,
        );
        expect(actor.role, ActorRole.parent);
        expect(actor.uid, 'auth-uid');
      }
    });
  });

  group('learningCommandsProvider', () {
    late InMemoryLearningWritePort port;
    late InMemoryChangeLogRepository changeLog;

    List<Override> ready({bool lockSettings = true}) => [
      learningCommandClockProvider.overrideWithValue(() => engineAt(600)),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      activeAuthUidProvider.overrideWith((ref) async => 'auth-uid'),
      learningWritePortProvider.overrideWith((ref) async => port),
      changeLogRepositoryProvider.overrideWith((ref) async => changeLog),
      governedDocReaderProvider.overrideWith((ref) async => changeLog),
      subTrackRepositoryProvider.overrideWith(
        (ref) async => InMemorySubTrackRepository(),
      ),
      oversizedGovernedWritePortProvider.overrideWith(
        (ref) async => FakeOversizedGovernedWritePort(),
      ),
      pointsAmountReaderProvider.overrideWith((ref) async => _FixedPoints()),
      learningEventRepositoryProvider.overrideWith(
        (ref) async => InMemoryLearningEventRepository(),
      ),
      activeProfileProvider.overrideWith(
        (ref) async => _profile(ProfileMode.adult),
      ),
      corporaProvider.overrideWith(
        (ref) async => <String, Corpus>{engineCurriculum: mishnayosCorpus()},
      ),
      if (lockSettings)
        learnerLockSettingsProvider.overrideWith(
          (ref, _) => Stream.value(c0SettingsHistory()),
        ),
    ];

    setUp(() {
      port = InMemoryLearningWritePort();
      changeLog = InMemoryChangeLogRepository();
    });

    test('null while no learner is active', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
      );
      expect(
        await settledAsync(container, learningCommandsProvider),
        const AsyncData<LearningCommands?>(null),
      );
    });

    test('binds DefaultLearningCommands to the scope and the live uid; a '
        'capture lands through the write port with its pts_ entry', () async {
      final container = ProviderContainer.test(overrides: ready());
      final commands = (await settledAsync(
        container,
        learningCommandsProvider,
      )).value;
      expect(commands, isA<DefaultLearningCommands>());
      final result = await commands!.capture(
        curriculumId: engineCurriculum,
        refs: const ['Mishnah Berakhot 1:1'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );
      expect(result, isA<CaptureSuccess>());
      final (scope, chunk) = port.commits.single;
      expect(scope, c0Scope());
      expect(chunk.events.single.actor.uid, 'auth-uid');
      expect(chunk.events.single.actor.role, ActorRole.parent);
      expect(chunk.awards.single.amount, 7);
    });

    test('wires the governed half (DNI-470): a governed change lands in '
        'the change log as the session actor', () async {
      final container = ProviderContainer.test(overrides: ready());
      final commands = (await settledAsync(
        container,
        learningCommandsProvider,
      )).value!;
      final result = await commands.applyGovernedChange(
        GovernedAction(const [
          GovernedEntityChange(
            entity: GovernedEntity.mainTrackProgram,
            entityId: engineCurriculum,
            docs: [
              GovernedDocPatch(
                collection: 'profile_programs',
                docId: engineCurriculum,
                fields: {
                  'curriculum_id': engineCurriculum,
                  'program_id': 'daf',
                },
              ),
            ],
          ),
        ]),
      );
      expect(result, isA<CaptureSuccess>());
      final (scope, batch) = changeLog.batches.single;
      expect(scope, c0Scope());
      expect(batch.entry.actor.uid, 'auth-uid');
      expect(batch.entry.actor.role, ActorRole.parent);
      expect(batch.entry.at, engineAt(600));
    });

    test('fails closed (locked, nothing written) while the settings '
        'history is unavailable', () async {
      final container = ProviderContainer.test(
        overrides: [
          ...ready(lockSettings: false),
          learnerLockSettingsProvider.overrideWith(
            (ref, _) => Stream.error(StateError('not ready')),
          ),
        ],
      );
      final commands = (await settledAsync(
        container,
        learningCommandsProvider,
      )).value!;
      expect(
        await commands.capture(
          curriculumId: engineCurriculum,
          refs: const ['Mishnah Berakhot 1:1'],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
        ),
        isA<CaptureLocked>(),
      );
      expect(port.attempts, isEmpty);
    });
  });
}
