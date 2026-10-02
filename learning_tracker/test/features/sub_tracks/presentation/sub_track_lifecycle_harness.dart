/// Shared rig for the Story 2.8 (DNI-499) lifecycle widget tests: the real
/// governed `SubTrackCommands` over an in-memory sub-track repository,
/// exposed through `learningCommandsProvider`, and the lifecycle reads
/// pinned to a learner today, viewer and deadline.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_lifecycle_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_sync_panel.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

/// The learner's civil today in every lifecycle widget test.
const lifecycleToday = '2026-10-01';

/// Ground of the seeded tracks.
const lifecycleGround = [NodeEntry(level: 'masechta', ref: 'Berakhot')];

/// A ULID for fixture [n].
String lifecycleId(int n) =>
    '01JWXDGT000000000000000${n.toString().padLeft(3, '0')}';

/// The 2026–27 school year: Sep–Jul, 8 a week, 36 weeks, learns on Shabbos.
SubTrack schoolYear({
  int n = 1,
  String name = 'School',
  int academicYear = 2026,
  String? windowStart,
  String? windowEnd,
  bool openEnded = false,
  SubTrackEndReason? endReason,
}) => SubTrack(
  id: lifecycleId(n),
  curriculumId: 'shas',
  name: name,
  type: SubTrackType.schoolYear,
  academicYear: academicYear,
  windowStart: windowStart ?? '$academicYear-09-01',
  windowEnd: openEnded ? null : (windowEnd ?? '${academicYear + 1}-07-31'),
  ratePerWeek: 8,
  weeksPerYear: 36,
  learnsOnShabbos: true,
  ground: lifecycleGround,
  lastChangeId: ulidE,
  endedAt: endReason == null ? null : t1,
  endReason: endReason,
);

/// A live ongoing sub-track.
SubTrack ongoing({
  int n = 2,
  String name = 'Night seder',
  String? windowEnd,
  SubTrackEndReason? endReason,
}) => SubTrack(
  id: lifecycleId(n),
  curriculumId: 'shas',
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-01-01',
  windowEnd: windowEnd,
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: lifecycleGround,
  lastChangeId: ulidE,
  endedAt: endReason == null ? null : t1,
  endReason: endReason,
);

/// `LearningCommands` whose sub-track commands are the real governed
/// [SubTrackCommands]; [calls] names every lifecycle call and [nextResult]
/// scripts one refusal (one-shot) without writing.
final class SubTrackLifecycleCommands implements LearningCommands {
  /// Wraps [inner].
  SubTrackLifecycleCommands(this.inner);

  /// The real commands.
  final SubTrackCommands inner;

  /// Every lifecycle call, in order.
  final List<String> calls = [];

  /// The result of the next call (one-shot), returned without writing.
  CaptureResult? nextResult;

  Future<CaptureResult> _run(
    String name,
    Future<CaptureResult> Function() command,
  ) async {
    calls.add(name);
    final scripted = nextResult;
    if (scripted != null) {
      nextResult = null;
      return scripted;
    }
    return command();
  }

  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    bool addNextYear = false,
  }) => _run(
    addNextYear ? 'createSubTrack(addNextYear)' : 'createSubTrack',
    () => inner.createSubTrack(
      draft,
      subTrackId: subTrackId,
      addNextYear: addNextYear,
    ),
  );

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) =>
      _run('editSubTrack', () => inner.editSubTrack(subTrackId, edit));

  @override
  Future<CaptureResult> endSubTrack(String subTrackId) =>
      _run('endSubTrack', () => inner.endSubTrack(subTrackId));

  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      _run('deleteSubTrack', () => inner.deleteSubTrack(subTrackId));

  @override
  Stream<List<PendingFailure>> watchPendingFailures() =>
      inner.watchPendingFailures();

  @override
  Future<CaptureResult> retry(String pendingFailureId) =>
      _run('retry', () => inner.retry(pendingFailureId));

  @override
  Future<bool> whenSubTrackChangeConfirmed(String changeId) =>
      inner.whenConfirmed(changeId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not a lifecycle command: ${invocation.memberName}',
  );
}

/// [InMemorySubTrackRepository] and [InMemoryGovernedIntentRepository]
/// close their per-listener controllers in an async `onCancel`, which the
/// widget tests' fake clock never completes, so a `.first` read (the
/// commands' complete-read wait) would time out. These views cancel without
/// awaiting the inner subscription; writes go straight through.
final class _FakeAsyncSubTracks implements SubTrackRepository {
  _FakeAsyncSubTracks(this.inner, {this.readOverride});

  final InMemorySubTrackRepository inner;

  /// When it returns a stream, the reads use it instead of [inner].
  final Stream<CompleteRead<SubTrack>>? Function()? readOverride;

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) =>
      readOverride?.call() ??
      inner
          .watchAll(scope)
          .asBroadcastStream(onCancel: (s) => unawaited(s.cancel()));

  @override
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change) =>
      inner.applyGovernedChange(scope, change);
}

final class _FakeAsyncIntent implements GovernedIntentRepository {
  _FakeAsyncIntent(this.inner);

  final InMemoryGovernedIntentRepository inner;

  @override
  Stream<LearnerIntent> watch(LearnerScope scope) => inner
      .watch(scope)
      .asBroadcastStream(onCancel: (s) => unawaited(s.cancel()));
}

/// One learner's sub-tracks, commands and lifecycle reads.
final class LifecycleWorld {
  /// Seeds [tracks] for the owner scope.
  LifecycleWorld(
    List<SubTrack> tracks, {
    this.viewer = SubTrackLifecycleViewer.parent,
    this.deadline,
    this.today = lifecycleToday,
  }) {
    repo.seed(scope, tracks);
    intent.emit(
      scope,
      LearnerIntent(
        settings: c0Settings,
        mainTracks: {
          'shas': MainTrackIntent(
            curriculumId: 'shas',
            track: MainTrack(
              curriculumId: 'shas',
              state: MainTrackState.active,
            ),
          ),
        },
        goals: const {},
      ),
    );
  }

  /// The owner scope.
  final scope = c0Scope();

  /// The sub-track store.
  final repo = InMemorySubTrackRepository();

  /// The governed intent (no calendar program).
  final intent = InMemoryGovernedIntentRepository();

  /// AD-47 events.
  final analytics = RecordingLearningAnalytics();

  /// The viewer.
  final SubTrackLifecycleViewer viewer;

  /// The curriculum's live deadline.
  final String? deadline;

  /// The learner's civil today.
  final String today;

  /// When set, the lifecycle READS (not the commands) see this stream
  /// instead of the store: a failing or never-completing read.
  Stream<CompleteRead<SubTrack>> Function()? readOverride;

  var _n = 0;

  /// The lifecycle commands.
  late final commands = SubTrackLifecycleCommands(
    SubTrackCommands(
      scope: scope,
      actor: parentActor,
      subTracks: _FakeAsyncSubTracks(repo),
      intent: _FakeAsyncIntent(intent),
      today: () => today,
      nowUtc: () => DateTime.utc(2026, 10, 1, 9),
      newId: () =>
          '01JNEW00000000000000000${(++_n).toString().padLeft(3, '0')}',
      analytics: analytics,
      ackTimeout: const Duration(milliseconds: 20),
      readTimeout: const Duration(seconds: 1),
    ),
  );

  /// The stored sub-tracks.
  List<SubTrack> get stored => repo.tracksOf(scope);

  /// The provider overrides of this world.
  List<Override> get overrides => [
    activeLearnerScopeProvider.overrideWith((ref) async => scope),
    subTrackRepositoryProvider.overrideWith(
      (ref) async =>
          _FakeAsyncSubTracks(repo, readOverride: () => readOverride?.call()),
    ),
    subTrackLifecycleTodayProvider.overrideWith((ref) => today),
    subTrackLifecycleViewerProvider.overrideWith((ref) => viewer),
    subTrackCurriculumDeadlineProvider.overrideWith(
      (ref, _) => Stream.value(deadline),
    ),
    learningCommandsProvider.overrideWith((ref) async => commands),
  ];

  /// Releases the ports.
  Future<void> dispose() async {
    await commands.inner.dispose();
    await repo.dispose();
    await intent.dispose();
  }
}

/// A stand-in hub page: the queued-write panel, then one button per [ids]
/// opening its detail through [open], so a test can assert the return to
/// the hub.
class LifecycleHubHost extends StatelessWidget {
  /// Creates the host.
  const LifecycleHubHost({super.key, required this.ids, required this.open});

  /// The sub-tracks to offer.
  final List<String> ids;

  /// Opens a detail.
  final Future<void> Function(BuildContext context, String id) open;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      key: const ValueKey('lifecycleHubHost'),
      children: [
        const SubTrackLifecycleSyncPanel(),
        for (final id in ids)
          TextButton(
            key: ValueKey('open:$id'),
            onPressed: () => open(context, id),
            child: Text('open $id'),
          ),
      ],
    ),
  );
}
