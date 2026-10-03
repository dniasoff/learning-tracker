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
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
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

  group('learnerToday', () {
    test('is the civil date in the learner zone once the settings history '
        'is known, else the UTC date (never the device offset)', () {
      final lateUtc = DateTime.utc(2026, 9, 1, 23, 30);
      final history = LearnerSettingsHistory.constant(
        const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'Asia/Jerusalem',
        ),
      );
      expect(learnerToday(lateUtc, history), '2026-09-02');
      expect(learnerToday(lateUtc, null), '2026-09-01');
    });
  });

  group('learningCommandsProvider', () {
    late InMemoryLearningWritePort port;
    late InMemoryChangeLogRepository changeLog;
    late InMemorySubTrackRepository subTracks;
    late InMemoryGovernedIntentRepository intent;

    List<Override> ready({
      bool lockSettings = true,
      bool corpora = true,
      Override? subTrackRepo,
      DateTime? now,
    }) => [
      learningCommandClockProvider.overrideWithValue(
        () => now ?? engineAt(600),
      ),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      activeAuthUidProvider.overrideWith((ref) async => 'auth-uid'),
      learningWritePortProvider.overrideWith((ref) async => port),
      changeLogRepositoryProvider.overrideWith((ref) async => changeLog),
      governedDocReaderProvider.overrideWith((ref) async => changeLog),
      governedIntentRepositoryProvider.overrideWith((ref) async => intent),
      oversizedGovernedWritePortProvider.overrideWith(
        (ref) async => FakeOversizedGovernedWritePort(),
      ),
      pointsAmountReaderProvider.overrideWith((ref) async => _FixedPoints()),
      learningEventRepositoryProvider.overrideWith(
        (ref) async => InMemoryLearningEventRepository(),
      ),
      subTrackRepo ??
          subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
      activeProfileProvider.overrideWith(
        (ref) async => _profile(ProfileMode.adult),
      ),
      if (corpora)
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
      subTracks = InMemorySubTrackRepository();
      intent = InMemoryGovernedIntentRepository()
        ..emit(
          c0Scope(),
          LearnerIntent(
            settings: c0Settings,
            mainTracks: {engineCurriculum: engineIntent()},
            goals: const {},
          ),
        );
      addTearDown(() async {
        await subTracks.dispose();
        await intent.dispose();
      });
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

    test('the gate reads learnerLockSettingsProvider: an unreadable '
        'learner settings doc fails a capture closed (DNI-470 AC-7)', () async {
      final container = ProviderContainer.test(
        overrides: [
          ...ready(lockSettings: false),
          learnerSettingsReaderProvider.overrideWith(
            (ref) async => _UnreadableSettings(),
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

    group('DNI-481 AC-6: the gate judges the TARGET learner (AD-36 write '
        'path)', () {
      // Saturday 2026-09-05 20:00Z: locked in Lakewood, open in Jerusalem.
      final saturdayEvening = DateTime.utc(2026, 9, 5, 20);
      final sibling = LearnerScope(
        ownerUid: c0Scope().ownerUid,
        profileId: '01ARZ3NDEKTSV4RRFFQ69G5FB2',
      );

      Future<CaptureResult> captureWith({
        required LearnerSettingsHistory target,
        required LearnerSettingsHistory other,
      }) async {
        final container = ProviderContainer.test(
          overrides: [
            ...ready(lockSettings: false, now: saturdayEvening),
            learnerLockSettingsProvider.overrideWith(
              (ref, scope) => Stream.value(
                scope == c0Scope()
                    ? target
                    : scope == sibling
                    ? other
                    : throw StateError('unexpected scope $scope'),
              ),
            ),
          ],
        );
        final commands = (await settledAsync(
          container,
          learningCommandsProvider,
        )).value!;
        return commands.capture(
          curriculumId: engineCurriculum,
          refs: const ['Mishnah Berakhot 1:1'],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
        );
      }

      test('a locked sibling does not lock the target learner', () async {
        final result = await captureWith(
          target: constantHistory(jerusalem),
          other: constantHistory(lakewood),
        );
        expect(result, isNot(isA<CaptureLocked>()));
        expect(port.attempts, isNotEmpty);
      });

      test('a locked target refuses before any write', () async {
        final result = await captureWith(
          target: constantHistory(lakewood),
          other: constantHistory(jerusalem),
        );
        expect(result, isA<CaptureLocked>());
        expect(port.attempts, isEmpty);
      });
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

    group('wires the governed sub-track commands (DNI-492, DNI-499): the '
        'lifecycle actions are saved, never answered onlineRequired', () {
      // The 2026-27 school year; the clock is 2026-09-01 10:00 UTC.
      final school = SubTrack(
        id: ulidD,
        curriculumId: engineCurriculum,
        name: 'School',
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        windowStart: '2026-09-01',
        windowEnd: '2027-07-31',
        ratePerWeek: 8,
        weeksPerYear: 36,
        learnsOnShabbos: true,
        ground: const [],
        lastChangeId: ulidE,
      );

      Future<LearningCommands> commandsOf() async {
        subTracks.seed(c0Scope(), [school]);
        final container = ProviderContainer.test(overrides: ready());
        return (await settledAsync(container, learningCommandsProvider)).value!;
      }

      test('Add next year creates the 2027-28 school year and reports '
          'subtrack_lifecycle add_next_year', () async {
        final commands = await commandsOf();
        final result = await commands.createSubTrack(
          const SubTrackDraft(
            curriculumId: engineCurriculum,
            name: 'School',
            type: SubTrackType.schoolYear,
            academicYear: 2027,
            windowStart: '2027-09-01',
            windowEnd: '2028-07-31',
            ratePerWeek: 8,
            weeksPerYear: 36,
            learnsOnShabbos: true,
            ground: [],
          ),
          subTrackId: ulidC,
          nextYearOf: ulidD,
        );
        expect(result, isA<CaptureSuccess>());
        expect((result as CaptureSuccess).queued, isFalse);
        final created = subTracks
            .tracksOf(c0Scope())
            .singleWhere((t) => t.id == ulidC);
        expect(created.academicYear, 2027);
        final (scope, entry) = subTracks.entries.single;
        expect(scope, c0Scope());
        expect(entry.actor.uid, 'auth-uid');
        expect(entry.actor.role, ActorRole.parent);
        await pumpEventQueue();
        expect(
          analytics.lastParamsOf(AnalyticsEvent.subTrackLifecycle)?['action'],
          'add_next_year',
        );
      });

      test('End writes the ended tombstone', () async {
        final commands = await commandsOf();
        final result = await commands.endSubTrack(ulidD);
        expect(result, isA<CaptureSuccess>());
        final ended = subTracks.tracksOf(c0Scope()).single;
        expect(ended.endedAt, isNotNull);
        expect(ended.endReason, SubTrackEndReason.ended);
      });

      test('Delete writes the deleted tombstone', () async {
        final commands = await commandsOf();
        final result = await commands.deleteSubTrack(ulidD);
        expect(result, isA<CaptureSuccess>());
        final deleted = subTracks.tracksOf(c0Scope()).single;
        expect(deleted.endedAt, isNotNull);
        expect(deleted.endReason, SubTrackEndReason.deleted);
      });
    });

    test('wires the governed sub-track commands: a parent ground reorder '
        'through editSubTrack is saved, not answered onlineRequired '
        '(DNI-497)', () async {
      subTracks.seed(c0Scope(), [
        SubTrack(
          id: ulidD,
          curriculumId: engineCurriculum,
          name: 'School',
          type: SubTrackType.ongoing,
          windowStart: '2026-09-01',
          ratePerWeek: 3,
          weeksPerYear: 40,
          learnsOnShabbos: false,
          ground: const [berakhot1, peah],
          lastChangeId: ulidE,
        ),
      ]);
      final container = ProviderContainer.test(overrides: ready());
      final commands = (await settledAsync(
        container,
        learningCommandsProvider,
      )).value!;
      final result = await commands.editSubTrack(
        ulidD,
        const SubTrackEdit(ground: [peah, berakhot1]),
      );
      expect(result, isA<CaptureSuccess>());
      expect((result as CaptureSuccess).queued, isFalse);
      expect(subTracks.tracksOf(c0Scope()).single.ground, const [
        peah,
        berakhot1,
      ]);
      final (scope, entry) = subTracks.entries.single;
      expect(scope, c0Scope());
      expect(entry.actor.uid, 'auth-uid');
      expect(entry.actor.role, ActorRole.parent);
    });

    test('a sub-track create and edit save through the production '
        'corporaProvider while it cannot answer (DNI-496): the corpus '
        'is treated as absent, not as a failed save', () async {
      final container = ProviderContainer.test(
        overrides: ready(corpora: false),
      );
      expect(
        await settledAsync(container, corporaProvider),
        isA<AsyncError<Map<String, Corpus>>>(),
      );
      final commands = (await settledAsync(
        container,
        learningCommandsProvider,
      )).value!;

      final created = await commands.createSubTrack(
        const SubTrackDraft(
          curriculumId: engineCurriculum,
          name: 'Chavrusa',
          type: SubTrackType.ongoing,
          windowStart: '2026-09-01',
          ratePerWeek: 5,
          weeksPerYear: 52,
          learnsOnShabbos: false,
          ground: [],
        ),
        subTrackId: ulidD,
      );
      expect(created, isA<CaptureSuccess>());
      expect((created as CaptureSuccess).queued, isFalse);

      final edited = await commands.editSubTrack(
        ulidD,
        const SubTrackEdit(ratePerWeek: 7),
      );
      expect(edited, isA<CaptureSuccess>());
      final saved = subTracks.tracksOf(c0Scope()).single;
      expect(saved.name, 'Chavrusa');
      expect(saved.ratePerWeek, 7);
      expect(subTracks.entries, hasLength(2));
    });
    test(
      'createSubTrack through the provider graph reads the governed '
      'intent and saves the new sub-track (DNI-497 follow-up fyh.169)',
      () async {
        final container = ProviderContainer.test(overrides: ready());
        final commands = (await settledAsync(
          container,
          learningCommandsProvider,
        )).value!;
        final result = await commands.createSubTrack(
          const SubTrackDraft(
            curriculumId: engineCurriculum,
            name: 'School',
            type: SubTrackType.ongoing,
            windowStart: '2026-09-01',
            ratePerWeek: 3,
            weeksPerYear: 40,
            learnsOnShabbos: false,
            ground: [peah],
          ),
          subTrackId: ulidD,
        );
        expect(result, isA<CaptureSuccess>());
        final created = subTracks.tracksOf(c0Scope()).single;
        expect(created.id, ulidD);
        expect(created.ground, const [peah]);
        expect(subTracks.entries.single.$2.actor.role, ActorRole.parent);
      },
    );

    for (final (label, unavailable) in <(String, Override)>[
      (
        'not ready',
        subTrackRepositoryProvider.overrideWith((ref) async => null),
      ),
      (
        'failed',
        subTrackRepositoryProvider.overrideWith(
          (ref) async => throw StateError('sub-track repository down'),
        ),
      ),
    ]) {
      test('a sub-track repository that is $label leaves ordinary captures '
          'working; only the sub-track commands answer onlineRequired '
          '(DNI-497)', () async {
        final container = ProviderContainer.test(
          overrides: ready(subTrackRepo: unavailable),
        );
        final commands = (await settledAsync(
          container,
          learningCommandsProvider,
        )).value;
        expect(commands, isA<DefaultLearningCommands>());
        expect(
          await commands!.capture(
            curriculumId: engineCurriculum,
            refs: const ['Mishnah Berakhot 1:1'],
            source: LearningEvent.sourceMain,
            dateState: DateState.dated,
          ),
          isA<CaptureSuccess>(),
        );
        expect(port.commits, hasLength(1));
        expect(
          await commands.editSubTrack(
            ulidD,
            const SubTrackEdit(ground: [peah, berakhot1]),
          ),
          const CaptureResult.onlineRequired(),
        );
      });
    }
  });
  group('ownerGovernedWriterProvider (DNI-476)', () {
    test('writes through the current LearningCommands', () async {
      final commands = FakeLearningCommands();
      final container = ProviderContainer(
        overrides: [
          learningCommandsProvider.overrideWith((ref) async => commands),
        ],
      );
      addTearDown(container.dispose);

      final writer = container.read(ownerGovernedWriterProvider);
      await writer.applyGovernedChange(
        GovernedAction([
          const GovernedEntityChange(
            entity: GovernedEntity.mainTrack,
            entityId: 'mishnayos',
            docs: [
              GovernedDocPatch(
                collection: 'curriculum_tracks',
                docId: 'mishnayos',
                fields: {'state': 'active'},
              ),
            ],
          ),
        ]),
      );
      expect(commands.calls.single.name, 'applyGovernedChange');
    });

    test(
      'throws not-ready (and writes nothing) while there are no commands',
      () async {
        final container = ProviderContainer(
          overrides: [
            learningCommandsProvider.overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container
              .read(ownerGovernedWriterProvider)
              .applyGovernedChange(
                GovernedAction([
                  const GovernedEntityChange(
                    entity: GovernedEntity.mainTrack,
                    entityId: 'mishnayos',
                    docs: [
                      GovernedDocPatch(
                        collection: 'curriculum_tracks',
                        docId: 'mishnayos',
                        fields: {'state': 'active'},
                      ),
                    ],
                  ),
                ]),
              ),
          throwsA(isA<GovernedWriterNotReadyException>()),
        );
      },
    );
  });
}

/// A learner whose settings doc cannot be read.
final class _UnreadableSettings implements LearnerSettingsReader {
  @override
  Stream<LearnerSettings> watch(LearnerScope scope) =>
      Stream.error(const FormatException('no time_zone'));
}
