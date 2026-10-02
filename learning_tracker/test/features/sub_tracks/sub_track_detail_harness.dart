/// Test harness for the sub-track detail (Story 2.6 / DNI-497).
///
/// Wires the detail's providers to in-memory repositories and the REAL
/// learner-state engine (`LearnerStateEngine.run` over the repositories'
/// complete reads, the C0 `learnerStateProvider` seam), so a reorder or
/// removal written through `editSubTrack` recomputes position, held ground
/// and the main-track schedule exactly as production will once DNI-474
/// fills the seam.
///
/// [DetailHarness.deadline] gives the curriculum a live deadline so the
/// engine computes capacity and shortfall (Story 2.3 / DNI-494).
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/in_memory_ports.dart';

/// Goals with a live deadline on [deadline], or none.
Map<String, CurriculumGoals> _goals(CivilDate? deadline) => {
  if (deadline != null)
    engineCurriculum: CurriculumGoals(
      deadline: DeadlineGoal(
        curriculumId: engineCurriculum,
        targetDate: deadline,
      ),
    ),
};

/// Forced AD-44 capacity outputs for one sub-track.
typedef CapacityValues = ({int capacity, int shortfall});

/// A sub-track over the fixture Mishnayos corpus.
SubTrack detailSubTrack(
  int id,
  String name,
  List<NodeEntry> ground, {
  String? windowEnd,
  bool ended = false,
  int lastChange = 900,
}) => SubTrack(
  id: engineUlid(id),
  curriculumId: engineCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  windowEnd: windowEnd,
  ratePerWeek: 3,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(id + lastChange),
  endedAt: ended ? engineAt(1) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

/// In-memory repositories plus the real engine behind the detail.
final class DetailHarness {
  /// The active learner.
  final LearnerScope scope = c0Scope();

  /// `sub_tracks` (seeding, written entries, scripted failures).
  final InMemorySubTrackRepository tracks = InMemorySubTrackRepository();

  /// [tracks] behind a watch that completes `first` / `firstWhere` under
  /// the widget tester's fake async (see [FakeAsyncSafeSubTrackRepository]).
  late final FakeAsyncSafeSubTrackRepository repository =
      FakeAsyncSafeSubTrackRepository(tracks, scope);

  /// `learning_events`.
  final InMemoryLearningEventRepository events =
      InMemoryLearningEventRepository();

  /// A live `goals/{c}_deadline` target date for the fixture curriculum,
  /// so the real engine (DNI-494) computes capacity and shortfall.
  CivilDate? deadline;

  /// Forced capacity/shortfall per sub-track id, over the engine's values
  /// (for audience cases the fixture's numbers do not reach).
  final Map<String, CapacityValues> capacities = {};

  /// The latest engine output, for assertions.
  LearnerState? lastState;

  /// Seeds [subTracks] and [learnEvents].
  void seed({
    List<SubTrack> subTracks = const [],
    List<LearningEvent> learnEvents = const [],
  }) {
    tracks.seed(scope, subTracks);
    events.seed(scope, learnEvents);
  }

  /// The engine's state of the fixture curriculum, as last published.
  CurriculumState get curriculum => lastState![engineCurriculum]!;

  /// Runs the engine whenever either complete read changes.
  Stream<LearnerState> _engine() {
    late StreamController<LearnerState> out;
    final subs = <StreamSubscription<Object?>>[];
    List<SubTrack>? latestTracks;
    List<LearningEvent>? latestEvents;
    void run() {
      final t = latestTracks;
      final e = latestEvents;
      if (t == null || e == null) return;
      final state = const LearnerStateEngine().run(
        engineInputs(events: e, subTracks: t, goals: _goals(deadline)),
      );
      lastState = _withCapacities(state);
      out.add(lastState!);
    }

    out = StreamController<LearnerState>(
      onListen: () {
        subs
          ..add(
            repository.watchAll(scope).listen((r) {
              if (r is CompleteReadReady<SubTrack>) {
                latestTracks = r.items;
                run();
              }
            }),
          )
          ..add(
            events.watchAll(scope).listen((r) {
              if (r is CompleteReadReady<LearningEvent>) {
                latestEvents = r.items;
                run();
              }
            }),
          );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        await out.close();
      },
    );
    return out.stream;
  }

  LearnerState _withCapacities(LearnerState state) {
    if (capacities.isEmpty) return state;
    return LearnerState(
      nowUtc: state.nowUtc,
      curricula: {
        for (final MapEntry(:key, :value) in state.curricula.entries)
          key: _CapacityCurriculumState(value, capacities),
      },
      countedEventIds: state.countedEventIds,
      earningEventIds: state.earningEventIds,
      lockIgnoredEventIds: state.lockIgnoredEventIds,
      rejectedRows: state.rejectedRows,
    );
  }

  /// Provider overrides for the detail.
  List<Override> overrides({
    SubTrackDetailRole role = SubTrackDetailRole.parent,
    LearningCommands? commands,
    Stream<LearnerState>? state,
    Stream<LearnerState> Function()? engine,
  }) => [
    activeLearnerScopeProvider.overrideWith((ref) async => scope),
    subTrackRepositoryProvider.overrideWith((ref) async => repository),
    learningEventRepositoryProvider.overrideWith((ref) async => events),
    corporaProvider.overrideWith(
      (ref) async => <String, Corpus>{engineCurriculum: mishnayosCorpus()},
    ),
    learnerStateProvider.overrideWith(
      (ref, _) => state ?? (engine ?? _engine)(),
    ),
    subTrackDetailRoleProvider.overrideWithValue(role),
    if (commands != null)
      learningCommandsProvider.overrideWith((ref) async => commands),
    ...rawLabelOverrides(),
  ];

  /// Closes the repositories.
  Future<void> dispose() async {
    await tracks.dispose();
    await events.dispose();
  }
}

/// A [CurriculumState] whose sub-track states carry the DNI-494 stand-in
/// capacity values; every other member is the real engine's.
final class _CapacityCurriculumState implements CurriculumState {
  _CapacityCurriculumState(this._inner, Map<String, CapacityValues> values)
    : subTracks = {
        for (final MapEntry(:key, :value) in _inner.subTracks.entries)
          key: switch (values[key]) {
            null => value,
            final v => SubTrackState(
              subTrackId: value.subTrackId,
              holdsGround: value.holdsGround,
              inForecast: value.inForecast,
              onHome: value.onHome,
              position: value.position,
              groundExhausted: value.groundExhausted,
              ticked: value.ticked,
              remainingPath: value.remainingPath,
              capacity: v.capacity,
              shortfall: v.shortfall,
            ),
          },
      };

  final CurriculumState _inner;

  @override
  final Map<String, SubTrackState> subTracks;

  @override
  String get curriculumId => _inner.curriculumId;
  @override
  bool get evaluated => _inner.evaluated;
  @override
  Set<LeafRef> get learntLeaves => _inner.learntLeaves;
  @override
  int get distinctLearnt => _inner.distinctLearnt;
  @override
  TriState triState(NodeEntry node) => _inner.triState(node);
  @override
  NodeEntry? get currentUnit => _inner.currentUnit;
  @override
  LeafRef? get mainTrackPosition => _inner.mainTrackPosition;
  @override
  List<LeafRef> get schedulableRefs => _inner.schedulableRefs;
  @override
  int get mainTrackRemaining => _inner.mainTrackRemaining;
  @override
  List<LeafRef> programAssignments(CivilDate date) =>
      _inner.programAssignments(date);
  @override
  List<LeafRef> programBacklog(CivilDate today) => _inner.programBacklog(today);
  @override
  List<ReviewDue> reviewsDue(CivilDate date) => _inner.reviewsDue(date);
  @override
  int? get dailyTarget => _inner.dailyTarget;
  @override
  double? get paceRate => _inner.paceRate;
  @override
  int? get shortfall => _inner.shortfall;
  @override
  Projection? get projection => _inner.projection;
  @override
  List<CompletedUnit> get completedUnits => _inner.completedUnits;
  @override
  CurriculumStreak? get streak => _inner.streak;
  @override
  Set<CurriculumValidationError> get validationErrors =>
      _inner.validationErrors;
  @override
  ReportProjection get report => _inner.report;
}

/// Runs the real engine over [track], [others] and [events] and builds the
/// detail the provider would publish (no providers involved).
SubTrackDetail engineDetail(
  SubTrack track, {
  List<SubTrack> others = const [],
  List<LearningEvent> events = const [],
  SubTrackDetailRole role = SubTrackDetailRole.parent,
}) {
  final all = [track, ...others];
  final state = const LearnerStateEngine().run(
    engineInputs(events: events, subTracks: all),
  );
  final c = state[engineCurriculum]!;
  return SubTrackDetail(
    track: track,
    role: role,
    noDeadline: c.dailyTarget == null,
    state: c.subTracks[track.id]!,
    ground: SubTrackGroundProjection.project(
      track: track,
      ground: track.ground,
      corpus: mishnayosCorpus(),
      learntLeaves: c.learntLeaves,
      countedLearns: [
        for (final e in events)
          if (state.countedEventIds.contains(e.id)) e,
      ],
      subTracks: all,
      holdsGround: (id) => c.subTracks[id]?.holdsGround ?? false,
    ),
  );
}

/// Label overrides: every ref renders as itself (no ContentIndex in tests).
List<Override> rawLabelOverrides() => [
  subTrackRefLabelProvider.overrideWith((ref, sefariaRef) => sefariaRef),
  subTrackNodeNameProvider.overrideWith((ref, sefariaRef) => sefariaRef),
];

/// The real engine's state over [subTracks] and [events].
LearnerState engineDetailState(
  SubTrack track, {
  List<SubTrack> others = const [],
  List<LearningEvent> events = const [],
}) => const LearnerStateEngine().run(
  engineInputs(events: events, subTracks: [track, ...others]),
);

/// A [SubTrackRepository] over [InMemorySubTrackRepository] whose
/// [watchAll] is an `async*` stream.
///
/// The shared in-memory fake closes its per-listener controller inside
/// `onCancel` and awaits it; under `testWidgets`' fake async that cancel
/// never finishes, so `firstWhere` (which awaits the cancel) never
/// completes and `SubTrackCommands` hangs. Writes and reads delegate.
final class FakeAsyncSafeSubTrackRepository implements SubTrackRepository {
  /// Wraps [inner] for [scope].
  FakeAsyncSafeSubTrackRepository(this.inner, this.scope);

  /// The wrapped fake.
  final InMemorySubTrackRepository inner;

  /// The only scope the harness uses.
  final LearnerScope scope;

  final _changes = StreamController<void>.broadcast(sync: true);

  List<RejectedRow> _rejected = const [];

  /// Makes every read report [rows] as undecodable.
  void seedRejected(List<RejectedRow> rows) {
    _rejected = List.of(rows);
    _changes.add(null);
  }

  CompleteReadReady<SubTrack> get _ready =>
      CompleteReadReady(inner.tracksOf(scope), rejected: _rejected);

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) async* {
    yield _ready;
    await for (final _ in _changes.stream) {
      yield _ready;
    }
  }

  @override
  Future<void> applyGovernedChange(
    LearnerScope scope,
    SubTrackChange change,
  ) async {
    // The fake applies the change to its local rows before its future
    // settles (an offline write is held until `settleHeld`), like
    // Firestore's latency compensation: show it at once, then again once
    // the "server" settled it (a refused offline write is reverted).
    final applied = inner.applyGovernedChange(scope, change);
    _changes.add(null);
    try {
      await applied;
    } finally {
      _changes.add(null);
    }
  }
}
