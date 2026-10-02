// C0 (DNI-524) contract test: AC-1 (command-layer purity), AC-2 (single
// declaration of every contract type), AC-4 (fakes behave per the ports),
// AC-5 (provider overrides) and AC-6 (the real pieces and exhaustive
// switches). The real pieces are covered in depth by their mirror tests;
// this file keeps one smoke check each so the contract has one entry
// point.
//
// The two static audits walk Directory('lib') (the R7 checker's
// documented tree-walking exemption); everything else exercises code.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/ports.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/fake_learner_state.dart';
import '../../helpers/learner_state/fake_learning_commands.dart';
import '../../helpers/learner_state/in_memory_ports.dart';
import '../../helpers/learner_state/learner_state_overrides.dart';
import '../../helpers/learner_state/provider_settle.dart';
import '../../helpers/learner_state_fixtures.dart';

/// AC-2: the DNI-464 public class/enum names C0 adopts.
const _dni464Types = [
  'Actor',
  'ActorRole',
  'ChangeLogConflictException',
  'ChangeLogEntry',
  'ChangedFieldKey',
  'CompleteRead',
  'CompleteReadLoading',
  'CompleteReadReady',
  'DateState',
  'EventStamper',
  'GovernedEntity',
  'LearnerScope',
  'LearnerSettings',
  'LearningEvent',
  'LearningEventConflictException',
  'LearningEventKind',
  'LearningEventRepository',
  'MainTrack',
  'MainTrackConfigDoc',
  'MainTrackIntent',
  'MainTrackOrderEntry',
  'MainTrackProgram',
  'MainTrackState',
  'NodeEntry',
  'PendingLearningEventWrite',
  'RejectedRow',
  'StorageFormatException',
  'SubTrack',
  'SubTrackChange',
  'SubTrackEndReason',
  'SubTrackNotFoundException',
  'SubTrackRepository',
  'SubTrackType',
];

/// The C0 class/enum names (ruling B4 step 2: one definition each).
const _c0Types = [
  'AchievementThreshold',
  'CalendarAssignment',
  'CaptureChildLimit',
  'CaptureGate',
  'CaptureLocked',
  'CaptureOnlineRequired',
  'CaptureRejected',
  'CaptureRejection',
  'CaptureResult',
  'CaptureSourceKind',
  'CaptureSuccess',
  'ChangeLogRepository',
  'ChangedSinceField',
  'CompletedUnit',
  'Corpus',
  'CorpusNode',
  'CurriculumGoals',
  'CurriculumState',
  'CurriculumStreak',
  'DeadlineGoal',
  'DocMode',
  'EventReplacement',
  'GateDecision',
  'GateLocked',
  'GateOpen',
  'GovernedAction',
  'GovernedBatch',
  'GovernedDocMerge',
  'GovernedDocPatch',
  'GovernedEntityChange',
  'GovernedIntentRepository',
  'GovernedWriteReceipt',
  'InMemoryCorpus',
  'LearnerIntent',
  'LearnerSettingsHistory',
  'LearnerState',
  'LearnerStateEngine',
  'LearnerStateInputs',
  'LearningAnalytics',
  'LearningCommands',
  'LearningWriteChunk',
  'LearningWritePort',
  'LockWindow',
  'LockWindowCaptureGate',
  'OnlineRequiredException',
  'OversizedGovernedEntry',
  'OversizedGovernedWrite',
  'OversizedGovernedWritePort',
  'PaceGoal',
  'PendingFailure',
  'PendingFailureReason',
  'PermanentWriteRejection',
  'PointsAward',
  'PointsLedgerRow',
  'PointsTotals',
  'Projection',
  'ProjectionStatus',
  'ReviewDue',
  'SettingsSpan',
  'SubTrackState',
  'TriState',
  'UtcInterval',
];

/// Top-level functions, typedefs and providers that must be declared once.
const _topLevel = [
  // DNI-464
  'effectiveAt',
  'isCivilDate',
  'isUlid',
  'activeLearnerScopeProvider',
  'learningEventRepositoryProvider',
  'subTrackRepositoryProvider',
  // C0
  'c0Stub',
  'CivilDate',
  'LeafRef',
  'civilDate',
  'lockWindows',
  'lockedDays',
  'catchUpWindow',
  'streakDay',
  'expandGround',
  'orderedLeaves',
  'holdsGround',
  'onHome',
  'inForecast',
  'pointsTotals',
  'newlyCrossedAchievements',
  'intentHistoryEntities',
  'changeLogRepositoryProvider',
  'governedIntentRepositoryProvider',
  'learningWritePortProvider',
  'oversizedGovernedWritePortProvider',
  'learnerStateEngineProvider',
  'corporaProvider',
  'learnerStateProvider',
  'activeLearnerStateProvider',
  'captureGateProvider',
  'learningAnalyticsProvider',
  'learningCommandsProvider',
  'learnerLockSettingsProvider',
];

Directory _lib() => Directory('lib').existsSync()
    ? Directory('lib')
    : Directory('learning_tracker/lib');

Iterable<(String, String)> _libSources() sync* {
  final root = _lib();
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield (
        entity.path.substring(entity.path.indexOf('lib/')),
        entity.readAsStringSync(),
      );
    }
  }
}

/// `{name: [paths…]}` of every top-level class/enum/mixin declaration.
Map<String, List<String>> _typeDeclarations() {
  final decl = RegExp(
    r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
    r'(?:class|enum|mixin)\s+(\w+)',
    multiLine: true,
  );
  final out = <String, List<String>>{};
  for (final (path, text) in _libSources()) {
    for (final m in decl.allMatches(text)) {
      out.putIfAbsent(m.group(1)!, () => []).add(path);
    }
  }
  return out;
}

/// Paths declaring the top-level function, typedef, const or final [name].
List<String> _topLevelDeclarations(String name) {
  final decl = RegExp(
    '^(?:typedef\\s+$name\\b'
    '|(?:final|const)\\s+(?:[\\w<>?, ]+\\s+)?$name\\s*='
    '|\\w[\\w<>?, ]*\\s+$name\\s*\\()',
    multiLine: true,
  );
  return [
    for (final (path, text) in _libSources())
      for (final _ in decl.allMatches(text)) path,
  ];
}

void main() {
  group('AC-1 / AC-2: contract surface', () {
    test('each DNI-464 and C0 type is declared exactly once in lib/', () {
      final decls = _typeDeclarations();
      final wrong = {
        for (final name in [..._dni464Types, ..._c0Types])
          if ((decls[name] ?? const []).length != 1) name: decls[name],
      };
      expect(wrong, isEmpty, reason: 'name: declaring paths');
    });

    test('each contract function, typedef and provider is declared '
        'exactly once in lib/', () {
      final wrong = {
        for (final name in _topLevel)
          if (_topLevelDeclarations(name).length != 1)
            name: _topLevelDeclarations(name),
      };
      expect(wrong, isEmpty, reason: 'name: declaring paths');
    });

    test('the command layer imports only lib/domain/learner_state/**, '
        'itself and dart:', () {
      final import = RegExp(
        r'''^(?:import|export)\s+'([^']+)';''',
        multiLine: true,
      );
      const allowed = [
        'dart:',
        'package:learning_tracker/domain/learner_state/',
        'package:learning_tracker/features/learning/domain/commands/',
      ];
      final bad = [
        for (final (path, text) in _libSources())
          if (path.startsWith('lib/features/learning/domain/commands/'))
            for (final m in import.allMatches(text))
              if (!allowed.any(m.group(1)!.startsWith) &&
                  m.group(1)!.contains(':'))
                '$path → ${m.group(1)}',
      ];
      expect(bad, isEmpty);
    });
  });

  group('AC-4: in-memory fakes', () {
    late LearnerScope scope;
    setUp(() => scope = c0Scope());

    test('the fakes implement their ports', () {
      expect(InMemoryLearningEventRepository(), isA<LearningEventRepository>());
      expect(InMemorySubTrackRepository(), isA<SubTrackRepository>());
      expect(InMemoryChangeLogRepository(), isA<ChangeLogRepository>());
      expect(
        InMemoryGovernedIntentRepository(),
        isA<GovernedIntentRepository>(),
      );
      expect(InMemoryLearningWritePort(), isA<LearningWritePort>());
      expect(
        FakeOversizedGovernedWritePort(),
        isA<OversizedGovernedWritePort>(),
      );
      expect(FakeLearningCommands(), isA<LearningCommands>());
      expect(FakeCaptureGate.open(), isA<CaptureGate>());
      expect(RecordingLearningAnalytics(), isA<LearningAnalytics>());
      expect(FakeCurriculumState(), isA<CurriculumState>());
    });

    group('InMemoryLearningEventRepository', () {
      test('watchAll emits loading, then ready, and re-emits on '
          'create', () async {
        final repo = InMemoryLearningEventRepository()
          ..seed(scope, [datedLearn(id: ulidB)]);
        final emissions = <CompleteRead<LearningEvent>>[];
        final sub = repo.watchAll(scope).listen(emissions.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();
        expect(emissions, [
          const CompleteReadLoading<LearningEvent>(),
          CompleteReadReady([datedLearn(id: ulidB)]),
        ]);

        await repo.create(scope, datedLearn());
        await pumpEventQueue();
        expect(
          emissions.last,
          CompleteReadReady([datedLearn(), datedLearn(id: ulidB)]),
        );
        expect(repo.created, [(scope, datedLearn())]);
      });

      test('an identical replay is a no-op; a different event at the same '
          'id conflicts', () async {
        final repo = InMemoryLearningEventRepository();
        await repo.create(scope, datedLearn());
        await repo.create(scope, datedLearn());
        expect(repo.created, hasLength(1));
        await expectLater(
          repo.create(scope, datedLearn(stage: 3)),
          throwsA(isA<LearningEventConflictException>()),
        );
        expect(repo.eventsOf(scope), [datedLearn()]);
      });

      test('scopes are isolated', () async {
        final repo = InMemoryLearningEventRepository();
        await repo.create(scope, datedLearn());
        expect(repo.eventsOf(c0Scope(ownerUid: 'other')), isEmpty);
      });
    });

    group('InMemorySubTrackRepository', () {
      SubTrackChange rateChange({Object? before = 7, String entryId = ulidD}) =>
          SubTrackChange.fields(
            subTrackId: ulidB,
            changedFields: {SubTrack.kRatePerWeek: 5},
            entry: ChangeLogEntry(
              id: entryId,
              entity: GovernedEntity.subTrack,
              entityId: ulidB,
              actionId: entryId,
              before: {'sub_tracks/$ulidB.rate_per_week': before},
              after: {'sub_tracks/$ulidB.rate_per_week': 5},
              at: t1,
              actor: parentActor,
            ),
          );

      test('applyGovernedChange merges the patch and records the '
          'entry', () async {
        final repo = InMemorySubTrackRepository()..seed(scope, [c0SubTrack()]);
        await repo.applyGovernedChange(scope, rateChange());
        final track = repo.tracksOf(scope).single;
        expect(track.ratePerWeek, 5);
        expect(track.lastChangeId, ulidD);
        expect(repo.entries.single.$2.id, ulidD);

        await repo.applyGovernedChange(scope, rateChange()); // replay
        expect(repo.entries, hasLength(1));
      });

      test('rejects a conflict, a missing target and a false '
          'baseline', () async {
        final repo = InMemorySubTrackRepository()..seed(scope, [c0SubTrack()]);
        await repo.applyGovernedChange(scope, rateChange());
        await expectLater(
          repo.applyGovernedChange(scope, rateChange(before: 6)),
          throwsA(isA<ChangeLogConflictException>()),
        );
        await expectLater(
          repo.applyGovernedChange(
            c0Scope(ownerUid: 'other'),
            rateChange(entryId: ulidE),
          ),
          throwsA(isA<SubTrackNotFoundException>()),
        );
        await expectLater(
          repo.applyGovernedChange(scope, rateChange(entryId: ulidE)),
          throwsA(isA<ChangeBaselineMismatchException>()),
        );
      });
    });

    group('InMemoryChangeLogRepository', () {
      ChangeLogEntry entry({
        String id = ulidD,
        GovernedEntity entity = GovernedEntity.mainTrackProgram,
        String? revertsActionId,
        int rate = 2,
      }) {
        final entityId = entity == GovernedEntity.goal ? 'g1' : 'mishnayos';
        final key = '${entity.collection}/$entityId.rate';
        return ChangeLogEntry(
          id: id,
          entity: entity,
          entityId: entityId,
          actionId: id,
          revertsActionId: revertsActionId,
          before: {key: null},
          after: {key: rate},
          at: t1,
          actor: parentActor,
        );
      }

      GovernedBatch batch(ChangeLogEntry e) => GovernedBatch(
        entry: e,
        merges: [
          GovernedDocMerge(
            collection: e.entity.collection,
            docId: e.entityId,
            fields: {'rate': e.after.values.single},
          ),
        ],
      );

      test('commitGoverned merges docs, feeds the intent history and is '
          'replay-safe', () async {
        final repo = InMemoryChangeLogRepository();
        final history = <CompleteRead<ChangeLogEntry>>[];
        final sub = repo.watchIntentHistory(scope).listen(history.add);
        addTearDown(sub.cancel);

        await repo.commitGoverned(scope, batch(entry()));
        await repo.commitGoverned(scope, batch(entry())); // replay
        await repo.commitGoverned(
          scope,
          batch(entry(id: ulidE, entity: GovernedEntity.goal)),
        );
        await pumpEventQueue();

        expect(repo.batches, hasLength(2));
        expect(repo.doc(scope, 'profile_programs', 'mishnayos'), {
          'rate': 2,
          'last_change_id': ulidD,
        });
        expect(history.first, const CompleteReadLoading<ChangeLogEntry>());
        // goal is not an intent-history entity.
        expect(history.last, CompleteReadReady([entry()]));
        expect(await repo.entriesOfAction(scope, ulidE), [
          entry(id: ulidE, entity: GovernedEntity.goal),
        ]);
        await expectLater(
          repo.commitGoverned(scope, batch(entry(rate: 3))),
          throwsA(isA<ChangeLogConflictException>()),
        );
      });

      test('watchIsReverted flips when an undo entry lands', () async {
        final repo = InMemoryChangeLogRepository();
        final reverted = <bool>[];
        final sub = repo.watchIsReverted(scope, ulidD).listen(reverted.add);
        addTearDown(sub.cancel);
        await repo.commitGoverned(scope, batch(entry()));
        await repo.commitGoverned(
          scope,
          batch(entry(id: ulidE, revertsActionId: ulidD, rate: 1)),
        );
        await pumpEventQueue();
        expect(reverted, [false, true]);
      });
    });

    test('InMemoryGovernedIntentRepository emits nothing until the intent '
        'is complete', () async {
      final repo = InMemoryGovernedIntentRepository();
      final seen = <LearnerIntent>[];
      final sub = repo.watch(scope).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen, isEmpty);
      final intent = LearnerIntent(
        settings: c0Settings,
        mainTracks: const {},
        goals: const {},
      );
      repo.emit(scope, intent);
      await pumpEventQueue();
      expect(seen, [intent]);
    });

    test('InMemoryLearningWritePort records chunks and fails the next '
        'commit permanently on demand', () async {
      final port = InMemoryLearningWritePort();
      final chunk = LearningWriteChunk(events: [datedLearn()]);
      await port.commit(scope, chunk);
      port.failNextWith(const PermanentWriteRejection('permission-denied'));
      await expectLater(
        port.commit(scope, chunk),
        throwsA(
          isA<PermanentWriteRejection>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await port.commit(scope, chunk);
      expect(port.chunks, [chunk, chunk]);
    });

    test('FakeOversizedGovernedWritePort requires online and echoes the '
        'request ids', () async {
      final port = FakeOversizedGovernedWritePort(online: false);
      const request = OversizedGovernedWrite(
        actionId: ulidD,
        actorRole: ActorRole.parent,
        entries: [
          OversizedGovernedEntry(
            entryId: ulidD,
            change: GovernedEntityChange(
              entity: GovernedEntity.mainTrackOrder,
              entityId: 'mishnayos',
              docs: [],
            ),
          ),
        ],
      );
      await expectLater(
        port.write(scope, request),
        throwsA(isA<OnlineRequiredException>()),
      );
      port.online = true;
      final receipt = await port.write(scope, request);
      expect(receipt.actionId, ulidD);
      expect(receipt.changeIds, [ulidD]);
      expect(port.requests, hasLength(1));
    });

    group('FakeLearningCommands', () {
      test('records every call and succeeds with fresh ULIDs by '
          'default', () async {
        final commands = FakeLearningCommands();
        final result = await commands.capture(
          curriculumId: 'mishnayos',
          refs: const ['a', 'b'],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
          learnedOn: '2026-09-01',
        );
        final again = await commands.voidEvent(ulidA);
        expect(commands.calls.map((c) => c.name), ['capture', 'voidEvent']);
        expect(commands.calls.first.args['refs'], ['a', 'b']);
        final ids = [
          ...(result as CaptureSuccess).eventIds,
          ...(again as CaptureSuccess).eventIds,
        ];
        expect(ids, hasLength(3));
        expect(ids.toSet(), hasLength(3));
        expect(ids.every(isUlid), isTrue);
      });

      test('nextResult is returned once', () async {
        final commands = FakeLearningCommands()
          ..nextResult = const CaptureResult.onlineRequired();
        expect(
          await commands.undoAction(ulidD),
          const CaptureResult.onlineRequired(),
        );
        expect(await commands.undoAction(ulidD), isA<CaptureSuccess>());
      });

      test('governed changes echo one change id per entity change', () async {
        final commands = FakeLearningCommands();
        final result = await commands.applyGovernedChange(
          GovernedAction(const [
            GovernedEntityChange(
              entity: GovernedEntity.mainTrackProgram,
              entityId: 'mishnayos',
              docs: [],
            ),
            GovernedEntityChange(
              entity: GovernedEntity.mainTrackOrder,
              entityId: 'mishnayos',
              docs: [],
            ),
          ]),
        );
        final success = result as CaptureSuccess;
        expect(success.changeIds, hasLength(2));
        expect(success.actionId, success.changeIds.first);
      });

      test('pendingFailures feeds watchPendingFailures', () async {
        final commands = FakeLearningCommands();
        addTearDown(commands.dispose);
        final seen = <List<PendingFailure>>[];
        final sub = commands.watchPendingFailures().listen(seen.add);
        addTearDown(sub.cancel);
        const failure = PendingFailure(
          id: 'p1',
          eventIds: [ulidA],
          changeIds: [],
          reason: PendingFailureReason.invalidArgument,
        );
        commands.pendingFailures.add(const [failure]);
        await pumpEventQueue();
        expect(seen, [
          [failure],
        ]);
      });
    });

    test('FakeCaptureGate and RecordingLearningAnalytics', () {
      final lock = LockWindow(t0, t1);
      final history = c0SettingsHistory();
      final open = FakeCaptureGate.open();
      expect(open.check(history, t0), const GateOpen());
      expect(FakeCaptureGate.locked(lock).check(history, t0), GateLocked(lock));
      expect(open.checks, [(history, t0)]);

      final analytics = RecordingLearningAnalytics()
        ..capture(
          curriculumId: 'mishnayos',
          sourceKind: CaptureSourceKind.subTrack,
          dateState: DateState.catchUp,
          count: 3,
        );
      expect(analytics.captures.single.count, 3);
      expect(analytics.captures.single.sourceKind, CaptureSourceKind.subTrack);
    });

    test('FakeCurriculumState defaults are empty and every member is '
        'settable', () {
      final empty = FakeCurriculumState();
      const node = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');
      expect(empty.evaluated, isTrue);
      expect(empty.learntLeaves, isEmpty);
      expect(empty.distinctLearnt, 0);
      expect(empty.triState(node), TriState.empty);
      expect(empty.programAssignments('2026-09-01'), isEmpty);
      expect(empty.programBacklog('2026-09-01'), isEmpty);
      expect(empty.reviewsDue('2026-09-01'), isEmpty);
      expect(empty.mainTrackRemaining, 0);
      expect(empty.projection, isNull);
      expect(empty.streak, isNull);

      final set = FakeCurriculumState(
        curriculumId: 'mishnayos',
        learntLeaves: const {'a', 'b'},
        triStates: {node: TriState.partial},
        reviews: const {
          '2026-09-01': [ReviewDue('a', 1)],
        },
        dailyTarget: 2,
        streak: const CurriculumStreak(current: 1, best: 4),
      );
      expect(set.distinctLearnt, 2);
      expect(set.triState(node), TriState.partial);
      expect(set.reviewsDue('2026-09-01'), const [ReviewDue('a', 1)]);
      expect(set.dailyTarget, 2);
      expect(fakeLearnerState(curricula: {'mishnayos': set})['mishnayos'], set);
    });
  });

  group('AC-5: provider overrides', () {
    test('consumers read the fakes through learnerStateOverrides', () async {
      final state = fakeLearnerState();
      final commands = FakeLearningCommands();
      final gate = FakeCaptureGate.open();
      final analytics = RecordingLearningAnalytics();
      final history = c0SettingsHistory();
      final container = ProviderContainer.test(
        overrides: learnerStateOverrides(
          scope: c0Scope(),
          state: state,
          commands: commands,
          lockSettings: history,
          gate: gate,
          analytics: analytics,
        ),
      );
      expect(
        (await settledAsync(container, activeLearnerStateProvider)).value,
        same(state),
      );
      expect(
        (await settledAsync(container, learningCommandsProvider)).value,
        same(commands),
      );
      expect(
        (await settledAsync(
          container,
          learnerLockSettingsProvider(c0Scope()),
        )).value,
        same(history),
      );
      expect(container.read(captureGateProvider), same(gate));
      expect(container.read(learningAnalyticsProvider), same(analytics));
    });

    test('with no scope the active learner state is AsyncData(null), and '
        'un-overridden stubs are AsyncError without crashing', () async {
      final container = ProviderContainer.test(
        overrides: learnerStateOverrides(),
      );
      expect(
        await settledAsync(container, activeLearnerStateProvider),
        const AsyncData<LearnerState?>(null),
      );
      // Filled by DNI-469: no learner scope → no commands (not ready).
      expect(
        await settledAsync(container, learningCommandsProvider),
        const AsyncData<LearningCommands?>(null),
      );
      expect(
        await settledAsync(container, corporaProvider),
        isAsyncC0Stub('DNI-474', 'corporaProvider'),
      );
      expect(container.read(learnerStateEngineProvider), isNotNull);
    });
  });

  group('AC-6: real pieces (smoke; depth in the mirror tests)', () {
    test('LearnerSettingsHistory.at and UtcInterval.contains', () {
      const later = LearnerSettings(
        profileId: profileUlid,
        timeZone: 'Asia/Jerusalem',
      );
      final h = LearnerSettingsHistory([
        const SettingsSpan(fromUtc: null, settings: c0Settings),
        SettingsSpan(fromUtc: t1, settings: later),
      ]);
      expect(h.at(t0), c0Settings);
      expect(h.at(t1), later);
      expect(LockWindow(t0, t1).contains(t1), isTrue);
    });

    test('InMemoryCorpus order', () {
      const a = NodeEntry(level: 'masechta', ref: 'A');
      const a1 = NodeEntry(level: 'perek', ref: 'A 1');
      const a2 = NodeEntry(level: 'perek', ref: 'A 2');
      final corpus = InMemoryCorpus('c', const [
        CorpusNode(a, [CorpusNode(a1), CorpusNode(a2)]),
      ]);
      expect(corpus.leavesUnder(a), ['A 1', 'A 2']);
      expect(corpus.parentOf(a2), a);
    });

    test('exhaustive switches over CaptureResult and GateDecision', () {
      String result(CaptureResult r) => switch (r) {
        CaptureSuccess() => 'success',
        CaptureLocked() => 'locked',
        CaptureChildLimit() => 'child',
        CaptureOnlineRequired() => 'online',
        CaptureRejected() => 'rejected',
      };
      String gate(GateDecision d) => switch (d) {
        GateOpen() => 'open',
        GateLocked() => 'locked',
      };
      expect(result(const CaptureResult.success()), 'success');
      expect(gate(const GateOpen()), 'open');
    });
  });
}
