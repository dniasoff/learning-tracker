/// A tiny stand-in for the learner-state engine and LearningCommands, so
/// the Story 2.9 (DNI-500) tests can drive +1 → event → derived row end to
/// end before DNI-465/469/474 fill the real engine and commands.
///
/// It applies only the AD-34/AD-36 rules the rows read: per-source distinct
/// ticks, position = first leaf of the ground not ticked in that source,
/// remaining path = position → end, voided events drop out, and a
/// lock-stamped event is kept but not counted.
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';

import '../learner_state/c0_fixtures.dart';
import '../learner_state/fake_learning_commands.dart';
import '../learner_state/in_memory_ports.dart';
import 'sub_track_home_fixtures.dart';

/// School's ground leaves, in order.
const schoolLeaves = [
  'Mishnah_Berakhot_1.1',
  'Mishnah_Berakhot_1.2',
  'Mishnah_Berakhot_1.3',
  berachos14,
  'Mishnah_Berakhot_1.5',
];

/// Rebbe's ground leaves, in order.
const rebbeLeaves = [peah21, 'Mishnah_Peah_2.2'];

/// The engine stand-in: emits a [LearnerState] after every change.
final class SubTrackTestEngine {
  /// Starts with School having ticked its first three leaves.
  SubTrackTestEngine({
    Map<String, List<String>>? grounds,
    Map<String, Set<String>>? ticked,
  }) : grounds = grounds ?? {schoolId: schoolLeaves, rebbeId: rebbeLeaves},
       _ticked = {
         for (final MapEntry(:key, :value)
             in (ticked ??
                     {
                       schoolId: schoolLeaves.take(3).toSet(),
                       rebbeId: <String>{},
                     })
                 .entries)
           key: {...value},
       };

  /// Ground leaves by sub-track id.
  final Map<String, List<String>> grounds;
  final Map<String, Set<String>> _ticked;
  final Map<String, (String source, String ref)> _events = {};
  final Set<String> _counted = {};
  final Set<String> _lockIgnored = {};

  /// When true, the next recorded event is found lock-stamped (one-shot).
  bool lockStampNext = false;

  /// When true, recorded events stay pending (queued offline, not yet
  /// synced): stored but neither counted nor lock-ignored until
  /// [syncPending] runs.
  bool holdPending = false;

  final List<String> _pending = [];

  /// Syncs every pending event; with [lockStamped] the engine finds them
  /// recorded inside a lock (the lock crossed before sync).
  void syncPending({bool lockStamped = false}) {
    for (final id in [..._pending]) {
      final (source, ref) = _events[id]!;
      if (lockStamped) {
        _lockIgnored.add(id);
      } else {
        _counted.add(id);
        _ticked.putIfAbsent(source, () => {}).add(ref);
      }
    }
    _pending.clear();
    _emit();
  }

  final _controller = StreamController<LearnerState>.broadcast();
  late LearnerState _state = _derive();

  /// The current state.
  LearnerState get state => _state;

  /// Every state, the current one first.
  Stream<LearnerState> watch() async* {
    yield _state;
    yield* _controller.stream;
  }

  /// Applies a captured event.
  void record(String eventId, String source, String ref) {
    _events[eventId] = (source, ref);
    if (holdPending) {
      _pending.add(eventId);
    } else if (lockStampNext) {
      lockStampNext = false;
      _lockIgnored.add(eventId);
    } else {
      _counted.add(eventId);
      _ticked.putIfAbsent(source, () => {}).add(ref);
    }
    _emit();
  }

  /// Voids [eventIds].
  void voidEvents(List<String> eventIds) {
    for (final id in eventIds) {
      final event = _events.remove(id);
      if (event == null || !_counted.remove(id)) continue;
      final (source, ref) = event;
      final stillTicked = _events.entries.any(
        (e) => _counted.contains(e.key) && e.value == (source, ref),
      );
      if (!stillTicked) _ticked[source]?.remove(ref);
    }
    _emit();
  }

  void _emit() {
    _state = _derive();
    _controller.add(_state);
  }

  LearnerState _derive() => homeLearnerState(
    [
      for (final MapEntry(key: id, value: leaves) in grounds.entries)
        _trackState(id, leaves),
    ],
    countedEventIds: {..._counted},
    lockIgnoredEventIds: {..._lockIgnored},
  );

  SubTrackState _trackState(String id, List<String> leaves) {
    final ticked = _ticked[id] ?? const <String>{};
    final index = leaves.indexWhere((l) => !ticked.contains(l));
    return homeState(
      id,
      position: index == -1 ? null : leaves[index],
      groundExhausted: leaves.isNotEmpty && index == -1,
      ticked: ticked.where(leaves.contains).length,
      remainingPath: index == -1 ? const [] : leaves.sublist(index),
    );
  }

  /// Closes the stream.
  Future<void> dispose() => _controller.close();
}

/// [LearningCommands] that records through [inner] and applies successful
/// captures and undos to [engine], like the real command + engine pair.
final class EngineBackedCommands implements LearningCommands {
  /// Creates the commands.
  EngineBackedCommands(this.engine);

  /// The engine stand-in.
  final SubTrackTestEngine engine;

  /// The recording fake (script [FakeLearningCommands.nextResult] here).
  final FakeLearningCommands inner = FakeLearningCommands();

  /// When set, captures wait for it before completing (a slow commit).
  Completer<void>? gate;

  @override
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
    bool skipRecorded = false,
    CaptureGesture gesture = CaptureGesture.plusOne,
    int taps = 1,
    int skippedCount = 0,
  }) async {
    final result = await inner.capture(
      curriculumId: curriculumId,
      refs: refs,
      nodes: nodes,
      source: source,
      dateState: dateState,
      learnedOn: learnedOn,
      stage: stage,
      skipRecorded: skipRecorded,
      gesture: gesture,
      taps: taps,
      skippedCount: skippedCount,
    );
    await gate?.future;
    if (result case CaptureSuccess(:final eventIds)) {
      for (var i = 0; i < eventIds.length; i++) {
        engine.record(eventIds[i], source, refs[i]);
      }
    }
    return result;
  }

  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) async {
    final result = await inner.undoEvents(eventIds);
    if (result is CaptureSuccess) engine.voidEvents(eventIds);
    return result;
  }

  @override
  Stream<List<PendingFailure>> watchPendingFailures() =>
      inner.watchPendingFailures();

  @override
  Future<CaptureResult> retry(String pendingFailureId) =>
      inner.retry(pendingFailureId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used by the sub-track rows');
}

/// Overrides wiring [engine] and [commands] for the active learner, with
/// School and Rebbe stored as live sub-tracks and the viewer as [role].
/// [states] replaces the engine's state stream (e.g. an error);
/// [groundOf] replaces a track's stored ground (e.g. none).
List<Override> subTrackEngineOverrides({
  required SubTrackTestEngine engine,
  required LearningCommands commands,
  SubTrackViewerRole role = SubTrackViewerRole.child,
  LearnerScope? scope,
  Stream<LearnerState> Function()? states,
  Map<String, List<NodeEntry>> groundOf = const {},
}) {
  final activeScope = scope ?? c0Scope();
  final repo = InMemorySubTrackRepository()
    ..seed(activeScope, [
      if (groundOf[schoolId] case final ground?)
        homeSubTrack(id: schoolId, ground: ground)
      else
        homeSubTrack(id: schoolId),
      homeSubTrack(
        id: rebbeId,
        name: 'Rebbe',
        ground:
            groundOf[rebbeId] ??
            const [NodeEntry(level: 'perek', ref: 'Mishnah_Peah_2')],
      ),
    ]);
  return [
    activeLearnerScopeProvider.overrideWith((ref) async => activeScope),
    subTrackRepositoryProvider.overrideWith((ref) async => repo),
    learnerStateProvider.overrideWith(
      (ref, _) => states?.call() ?? engine.watch(),
    ),
    learningCommandsProvider.overrideWith((ref) async => commands),
    subTrackViewerRoleProvider.overrideWithValue(role),
    ...positionLabelOverrides(),
  ];
}
