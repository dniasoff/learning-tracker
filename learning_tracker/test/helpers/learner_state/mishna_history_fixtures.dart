/// Hermetic fixtures for the Mishna-history tests (Story 1.13, DNI-475),
/// written against the C0 (DNI-524) fakes. TQ-6: fixed instants only.
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/providers/mishna_history_provider.dart';

import '../learner_state_fixtures.dart';
import '../learning_event_seed.dart';
import 'c0_fixtures.dart';
import 'fake_learner_state.dart';
import 'fake_learning_commands.dart';
import 'in_memory_ports.dart';
import 'learner_state_overrides.dart';

/// The curriculum under test.
const historyCurriculum = 'mishnayos';

/// The leaf whose history is shown.
const historyLeaf = 'Mishnah Berakhot 1:1';

/// Its sibling under the same perek.
const historySibling = 'Mishnah Berakhot 1:2';

/// The masechta node above both.
const historyMasechta = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');

/// Route arguments for [historyLeaf].
const MishnaHistoryArgs historyArgs = (
  curriculumId: historyCurriculum,
  leafRef: historyLeaf,
);

/// A two-leaf corpus: masechta → perek → [historyLeaf, historySibling].
Corpus historyCorpus() => InMemoryCorpus(historyCurriculum, const [
  CorpusNode(historyMasechta, [
    CorpusNode(NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 1'), [
      CorpusNode(NodeEntry(level: 'mishna', ref: historyLeaf)),
      CorpusNode(NodeEntry(level: 'mishna', ref: historySibling)),
    ]),
  ]),
]);

/// Event id number [n] (ascending ULIDs).
String eid(int n) => seqUlid(n);

/// The instant of day [day] of September 2026, 08:00 UTC.
DateTime onDay(int day) => DateTime.utc(2026, 9, day, 8);

/// A learn event on [historyLeaf] (or [ref]).
LearningEvent historyLearn(
  int n, {
  int day = 1,
  String ref = historyLeaf,
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  String? learnedOn,
  String? level,
}) => LearningEvent.learn(
  id: eid(n),
  curriculumId: historyCurriculum,
  ref: ref,
  source: source,
  dateState: dateState,
  learnedOn: dateState == DateState.beforeTracking
      ? null
      : learnedOn ?? '2026-09-${day.toString().padLeft(2, '0')}',
  recordedAt: onDay(day),
  actor: parentActor,
  level: level,
);

/// A void of event [target].
LearningEvent historyVoid(int n, String target, {int day = 20}) =>
    LearningEvent.voidOf(
      id: eid(n),
      targetId: target,
      recordedAt: onDay(day),
      actor: parentActor,
    );

/// An ended sub-track named [name].
SubTrack endedSubTrack({String id = ulidB, String name = 'Cheder shiur'}) {
  final live = c0SubTrack(id: id);
  return SubTrack(
    id: live.id,
    curriculumId: live.curriculumId,
    name: name,
    type: live.type,
    windowStart: live.windowStart,
    ratePerWeek: live.ratePerWeek,
    weeksPerYear: live.weeksPerYear,
    learnsOnShabbos: live.learnsOnShabbos,
    ground: live.ground,
    lastChangeId: live.lastChangeId,
    endedAt: t1,
    endReason: SubTrackEndReason.deleted,
  );
}

/// An engine output in which [learnt] decides whether [historyLeaf] is
/// learnt and [counted] / [lockIgnored] are the engine's event sets.
LearnerState historyState({
  bool learnt = true,
  Set<String> counted = const {},
  Set<String> lockIgnored = const {},
}) => fakeLearnerState(
  curricula: {
    historyCurriculum: FakeCurriculumState(
      curriculumId: historyCurriculum,
      learntLeaves: learnt ? {historyLeaf} : const {},
    ),
  },
  countedEventIds: counted,
  lockIgnoredEventIds: lockIgnored,
);

/// The in-memory repositories behind one history test.
final class HistoryPorts {
  /// Creates empty repositories.
  HistoryPorts() : scope = c0Scope();

  /// The active learner.
  final LearnerScope scope;

  /// The learning-event log.
  final events = InMemoryLearningEventRepository();

  /// The sub-tracks.
  final tracks = InMemorySubTrackRepository();

  /// Closes both repositories.
  Future<void> dispose() async {
    await events.dispose();
    await tracks.dispose();
  }
}

/// Overrides that wire [ports], [state], [commands], [viewer] and the
/// corpus into the real Mishna-history providers. A null [state] leaves
/// `learnerStateProvider` for the caller to override.
///
/// The learner's lock (AD-36) reads [lockSettings] (default
/// [c0SettingsHistory]) through [gate] (default: always open). Pass
/// `withLock: false` to leave both providers for the caller to override.
List<Override> historyOverrides(
  HistoryPorts ports, {
  required LearnerState? state,
  LearningCommands? commands,
  MishnaHistoryViewer viewer = MishnaHistoryViewer.parent,
  Corpus? corpus,
  CaptureGate? gate,
  LearnerSettingsHistory? lockSettings,
  bool withLock = true,
}) => [
  ...learnerStateOverrides(
    scope: ports.scope,
    state: state,
    commands: commands,
    gate: withLock ? gate ?? FakeCaptureGate.open() : null,
    lockSettings: withLock ? lockSettings ?? c0SettingsHistory() : null,
  ),
  learningEventRepositoryProvider.overrideWith((ref) async => ports.events),
  subTrackRepositoryProvider.overrideWith((ref) async => ports.tracks),
  corporaProvider.overrideWith(
    (ref) async => {historyCurriculum: corpus ?? historyCorpus()},
  ),
  mishnaHistoryViewerProvider.overrideWithValue(viewer),
];

/// A [LearningCommands] that delegates to [inner] but holds every write
/// until [release] is called, so a test can observe the optimistic state
/// while a correction is in flight.
final class GatedLearningCommands implements LearningCommands {
  /// Wraps [inner].
  GatedLearningCommands(this.inner);

  /// The recording fake.
  final FakeLearningCommands inner;

  Completer<void> _gate = Completer<void>();

  /// Lets the held write(s) complete.
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  /// Holds the next write again.
  void hold() => _gate = Completer<void>();

  Future<CaptureResult> _held(Future<CaptureResult> Function() run) async {
    final result = await run();
    await _gate.future;
    return result;
  }

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
  }) => _held(
    () => inner.capture(
      curriculumId: curriculumId,
      refs: refs,
      nodes: nodes,
      source: source,
      dateState: dateState,
      learnedOn: learnedOn,
      stage: stage,
      skipRecorded: skipRecorded,
    ),
  );

  @override
  Future<CaptureResult> voidEvent(String targetId) =>
      _held(() => inner.voidEvent(targetId));

  @override
  Future<CaptureResult> replace(
    String targetId,
    EventReplacement replacement,
  ) => _held(() => inner.replace(targetId, replacement));

  @override
  Future<CaptureResult> unlearn(String curriculumId, Set<LeafRef> leafSet) =>
      _held(() => inner.unlearn(curriculumId, leafSet));

  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) =>
      _held(() => inner.undoEvents(eventIds));

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) =>
      _held(() => inner.applyGovernedChange(action));

  @override
  Future<CaptureResult> undoAction(String actionId) =>
      _held(() => inner.undoAction(actionId));

  @override
  Future<CaptureResult> removeTrack(String curriculumId) =>
      _held(() => inner.removeTrack(curriculumId));

  @override
  Future<CaptureResult> reAddTrack(String curriculumId) =>
      _held(() => inner.reAddTrack(curriculumId));

  @override
  Future<BackupReplayResult> importBackup(BackupReplayInput input) =>
      inner.importBackup(input);
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    String? nextYearOf,
  }) => _held(
    () => inner.createSubTrack(
      draft,
      subTrackId: subTrackId,
      nextYearOf: nextYearOf,
    ),
  );

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) =>
      _held(() => inner.editSubTrack(subTrackId, edit));

  @override
  Future<CaptureResult> endSubTrack(String subTrackId) =>
      _held(() => inner.endSubTrack(subTrackId));

  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      _held(() => inner.deleteSubTrack(subTrackId));

  @override
  Stream<List<PendingFailure>> watchPendingFailures() =>
      inner.watchPendingFailures();

  @override
  Future<CaptureResult> retry(String pendingFailureId) =>
      _held(() => inner.retry(pendingFailureId));

  @override
  Future<bool> whenSubTrackChangeConfirmed(String changeId) =>
      inner.whenSubTrackChangeConfirmed(changeId);
}
