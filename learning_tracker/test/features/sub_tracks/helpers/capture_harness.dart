/// An end-to-end capture rig for the Story 2.10 (DNI-501) integration
/// tests: the real `DefaultLearningCommands` (CaptureGate, planning,
/// chunking, dispatcher) over an in-memory write port, and the real
/// `LearnerStateEngine` re-run over every committed event, so the
/// Learn-tab rows read positions, streaks and counts the engine derived.
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state/learner_state_overrides.dart';
import 'up_to_fixtures.dart';

/// A [LearningWritePort] that tells the rig after every commit.
final class _NotifyingPort implements LearningWritePort {
  _NotifyingPort(this.inner, this.onCommit);

  final InMemoryLearningWritePort inner;
  final void Function() onCommit;

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) async {
    await inner.commit(scope, chunk);
    onCommit();
  }
}

/// Reads whose event log is the seed plus everything committed.
final class _RigReads implements LearningCommandReads {
  _RigReads(this._rig);

  final CaptureRig _rig;
  late final _inner = FakeLearningCommandReads(
    history: _rig.settings,
    corpora: {engineCurriculum: _rig.corpus},
  );

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) =>
      _inner.settingsHistory(scope);

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) async => _rig.events;

  @override
  Future<Corpus?> corpus(String curriculumId) => _inner.corpus(curriculumId);

  @override
  Future<int> pointsAmount(LearnerScope s, String curriculumId, int? stage) =>
      _inner.pointsAmount(s, curriculumId, stage);
}

/// The rig.
final class CaptureRig {
  /// Creates the rig at [now] holding [subTracks] and [seed] events.
  CaptureRig({
    required DateTime now,
    this.subTracks = const [],
    List<LearningEvent> seed = const [],
    Corpus? corpus,
    LearnerSettingsHistory? settings,
    ActorRole role = ActorRole.child,
  }) : _now = now,
       _seed = List.of(seed),
       corpus = corpus ?? mishnayosCorpus(),
       settings = settings ?? c0SettingsHistory() {
    var seq = 50000;
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: Actor(uid: 'owner-uid', role: role, displayName: 'Child'),
      reads: _RigReads(this),
      writePort: _NotifyingPort(port, _publish),
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => _now,
      newUlid: (_) => engineUlid(seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
  }

  DateTime _now;
  final List<LearningEvent> _seed;

  /// The sub-tracks.
  final List<SubTrack> subTracks;

  /// The corpus of [engineCurriculum].
  final Corpus corpus;

  /// The learner's settings history.
  final LearnerSettingsHistory settings;

  /// The in-memory port behind the commands.
  final port = InMemoryLearningWritePort();

  /// The real commands.
  late final DefaultLearningCommands commands;

  final _states = StreamController<LearnerState>.broadcast();

  /// Moves the clock (commands and engine) to [now].
  set now(DateTime now) {
    _now = now;
    _publish();
  }

  /// Lands [event] in the persisted log as another device's write: the
  /// commands' reads and the engine see it, but this rig's port did not
  /// commit it.
  void recordElsewhere(LearningEvent event) {
    _seed.add(event);
    _publish();
  }

  /// The seed plus every committed event.
  List<LearningEvent> get events => [
    ..._seed,
    for (final c in port.chunks) ...c.events,
  ];

  /// The committed events only.
  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  /// The committed points entries.
  List<PointsAward> get awards => [for (final c in port.chunks) ...c.awards];

  /// The engine's current state.
  LearnerState get state => const LearnerStateEngine().run(
    engineInputs(
      events: events,
      subTracks: subTracks,
      corpora: {engineCurriculum: corpus},
      settingsHistory: settings,
      nowUtc: _now,
    ),
  );

  void _publish() {
    if (!_states.isClosed) _states.add(state);
  }

  Stream<LearnerState> _watch() async* {
    yield state;
    yield* _states.stream;
  }

  /// The provider overrides wiring the rig into a widget tree. Without
  /// [withCommands], `learningCommandsProvider` keeps its real body (null
  /// in a tutored session with no tutor write path bound).
  List<Override> overrides({bool withCommands = true}) => [
    ...learnerStateOverrides(
      scope: c0Scope(),
      commands: withCommands ? commands : null,
    ),
    learnerStateProvider.overrideWith((ref, _) => _watch()),
    activeSubTracksProvider.overrideWith((ref) => Stream.value(subTracks)),
    ...upToLabelOverrides(),
  ];

  /// Closes the rig.
  Future<void> dispose() async {
    await _states.close();
    await commands.dispose();
  }
}
