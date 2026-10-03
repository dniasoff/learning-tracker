/// Shared rig for the Story 2.8 (DNI-499) lifecycle widget tests on the
/// real DNI-497 sub-track detail and DNI-495 school-year form: the real
/// governed `SubTrackCommands` over the detail harness's in-memory
/// sub-track store, exposed through `learningCommandsProvider`, and the
/// real learner-state engine run on the learner's today.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_footer.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_sync_panel.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../sub_track_detail_harness.dart';

/// The learner's civil today in every lifecycle widget test.
const lifecycleToday = '2026-10-01';

/// The engine's clock on [lifecycleToday].
final lifecycleNow = DateTime.utc(2026, 10, 1, 9);

/// Ground of the seeded tracks.
const lifecycleGround = [peah];

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
  curriculumId: engineCurriculum,
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
  curriculumId: engineCurriculum,
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

  /// Runs once just before the next call reaches the real commands
  /// (one-shot): a change another device makes between render and save.
  FutureOr<void> Function()? beforeNext;

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
    final before = beforeNext;
    beforeNext = null;
    await before?.call();
    return command();
  }

  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    String? nextYearOf,
  }) => _run(
    nextYearOf != null
        ? 'createSubTrack(nextYearOf: $nextYearOf)'
        : 'createSubTrack',
    () => inner.createSubTrack(
      draft,
      subTrackId: subTrackId,
      nextYearOf: nextYearOf,
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

/// [InMemoryGovernedIntentRepository] closes its per-listener controllers
/// in an async `onCancel`, which the widget tests' fake clock never
/// completes, so a `.first` read (the commands' intent wait) would time
/// out. This view cancels without awaiting the inner subscription.
final class _FakeAsyncIntent implements GovernedIntentRepository {
  _FakeAsyncIntent(this.inner);

  final InMemoryGovernedIntentRepository inner;

  @override
  Stream<LearnerIntent> watch(LearnerScope scope) => inner
      .watch(scope)
      .asBroadcastStream(onCancel: (s) => unawaited(s.cancel()));
}

/// One learner's sub-tracks, commands, engine and lifecycle reads.
final class LifecycleWorld {
  /// Seeds [tracks] for the owner scope, viewed as [role].
  LifecycleWorld(
    List<SubTrack> tracks, {
    this.role = SubTrackDetailRole.parent,
    this.deadline,
    this.today = lifecycleToday,
  }) {
    detail
      ..nowUtc = lifecycleNow
      ..deadline = deadline
      ..seed(subTracks: tracks);
    intent.emit(
      scope,
      LearnerIntent(
        settings: c0Settings,
        mainTracks: {engineCurriculum: engineIntent()},
        goals: {
          if (deadline case final target?)
            engineCurriculum: CurriculumGoals(
              deadline: DeadlineGoal(
                curriculumId: engineCurriculum,
                targetDate: target,
              ),
            ),
        },
      ),
    );
  }

  /// The detail rig: the sub-track store, events and the real engine.
  final detail = DetailHarness();

  /// The owner scope.
  LearnerScope get scope => detail.scope;

  /// The sub-track store (offline, refusals, written entries).
  InMemorySubTrackRepository get repo => detail.tracks;

  /// The governed intent (no calendar program).
  final intent = InMemoryGovernedIntentRepository();

  /// AD-47 events.
  final analytics = RecordingLearningAnalytics();

  /// The viewer.
  final SubTrackDetailRole role;

  /// The curriculum's live deadline.
  final CivilDate? deadline;

  /// The learner's civil today.
  final CivilDate today;

  var _n = 0;

  /// The lifecycle commands.
  late final commands = SubTrackLifecycleCommands(
    SubTrackCommands(
      scope: scope,
      actor: parentActor,
      subTracks: detail.repository,
      intent: _FakeAsyncIntent(intent),
      today: () => today,
      nowUtc: () => lifecycleNow,
      newId: () =>
          '01JNEW00000000000000000${(++_n).toString().padLeft(3, '0')}',
      analytics: analytics,
      ackTimeout: const Duration(milliseconds: 20),
      readTimeout: const Duration(seconds: 1),
    ),
  );

  /// The stored sub-tracks.
  List<SubTrack> get stored => repo.tracksOf(scope);

  /// The provider overrides of this world. *Add next year* opens the real
  /// school-year form in its next-year mode, pushed on the navigator (the
  /// production opener pushes the same screen through the app router).
  List<Override> get overrides => [
    ...detail.overrides(role: role, commands: commands),
    governedIntentRepositoryProvider.overrideWith(
      (ref) async => _FakeAsyncIntent(intent),
    ),
    // The parent session follows [role] through `detail.overrides`
    // (`subTrackParentSessionProvider` is `parentSessionProvider`, which a
    // container may override only once).
    ...subTrackFormEnvironmentOverrides(today: today),
    subTrackNextYearFormProvider.overrideWithValue(
      (context, source) async =>
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => SchoolYearSubTrackFormScreen(
                curriculumId: source.curriculumId,
                nextYearOf: source.id,
              ),
            ),
          ) ??
          false,
    ),
  ];

  /// Releases the ports.
  Future<void> dispose() async {
    await commands.inner.dispose();
    await detail.dispose();
    await intent.dispose();
  }
}

/// A stand-in hub page: the queued-write panel, then one button per [ids]
/// pushing the real sub-track detail, so a test can assert the return to
/// the hub.
class LifecycleHubHost extends StatelessWidget {
  /// Creates the host.
  const LifecycleHubHost({super.key, required this.ids});

  /// The sub-tracks to offer.
  final List<String> ids;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      key: const ValueKey('lifecycleHubHost'),
      children: [
        const SubTrackLifecycleSyncPanel(),
        for (final id in ids)
          TextButton(
            key: ValueKey('open:$id'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SubTrackDetailScreen(subTrackId: id),
              ),
            ),
            child: Text('open $id'),
          ),
      ],
    ),
  );
}
