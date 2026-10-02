/// Hermetic fixtures for the DNI-465 learner-state engine tests: a small
/// Mishnayos-shaped corpus, event and intent builders, and fixed instants
/// (TQ-6: no wall clock).
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../learner_state_fixtures.dart';
import 'c0_fixtures.dart';

/// The fixture curriculum id.
const engineCurriculum = 'mishnayos';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// A valid, distinct ULID for [n] (0 ≤ n < 32^4); ULIDs sort by [n].
String engineUlid(int n) {
  final buf = StringBuffer();
  var v = n;
  for (var i = 0; i < 4; i++) {
    buf.write(_crockford[v % 32]);
    v ~/= 32;
  }
  return '01ARZ3NDEKTSV4RRFFQ69G${buf.toString().split('').reversed.join()}';
}

/// Instant [minutes] minutes after 2026-09-01T00:00Z.
DateTime engineAt(int minutes) =>
    DateTime.utc(2026, 9, 1).add(Duration(minutes: minutes));

/// Fixture nodes.
const zeraim = NodeEntry(level: 'seder', ref: 'Seder Zeraim');

/// Masechta Berakhot.
const berakhot = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');

/// Berakhot perek 1.
const berakhot1 = NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot 1');

/// Berakhot perek 2.
const berakhot2 = NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot 2');

/// Masechta Peah.
const peah = NodeEntry(level: 'masechta', ref: 'Mishnah Peah');

/// Seder Moed.
const moed = NodeEntry(level: 'seder', ref: 'Seder Moed');

/// Masechta Shabbat.
const shabbat = NodeEntry(level: 'masechta', ref: 'Mishnah Shabbat');

NodeEntry _leaf(String ref) => NodeEntry(level: 'mishnah', ref: ref);

/// The fixture Mishnayos corpus, in ContentIndex order:
///
/// * Seder Zeraim
///   * Berakhot: perek 1 (1:1, 1:2, 1:3), perek 2 (2:1, 2:2)
///   * Peah: perek 1 (1:1, 1:2)
/// * Seder Moed
///   * Shabbat: perek 1 (1:1, 1:2)
InMemoryCorpus mishnayosCorpus() => InMemoryCorpus(engineCurriculum, [
  CorpusNode(zeraim, [
    CorpusNode(berakhot, [
      CorpusNode(berakhot1, [
        CorpusNode(_leaf('Mishnah Berakhot 1:1')),
        CorpusNode(_leaf('Mishnah Berakhot 1:2')),
        CorpusNode(_leaf('Mishnah Berakhot 1:3')),
      ]),
      CorpusNode(berakhot2, [
        CorpusNode(_leaf('Mishnah Berakhot 2:1')),
        CorpusNode(_leaf('Mishnah Berakhot 2:2')),
      ]),
    ]),
    CorpusNode(peah, [
      CorpusNode(const NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1'), [
        CorpusNode(_leaf('Mishnah Peah 1:1')),
        CorpusNode(_leaf('Mishnah Peah 1:2')),
      ]),
    ]),
  ]),
  CorpusNode(moed, [
    CorpusNode(shabbat, [
      CorpusNode(const NodeEntry(level: 'chapter', ref: 'Mishnah Shabbat 1'), [
        CorpusNode(_leaf('Mishnah Shabbat 1:1')),
        CorpusNode(_leaf('Mishnah Shabbat 1:2')),
      ]),
    ]),
  ]),
]);

/// A `learn` event on [ref] at [minutes].
LearningEvent engineLearn(
  int id,
  String ref, {
  int minutes = 0,
  String curriculumId = engineCurriculum,
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  String? level,
  int? stage,
  int? originalMinutes,
  String learnedOn = '2026-09-01',
}) => LearningEvent.learn(
  id: engineUlid(id),
  curriculumId: curriculumId,
  ref: ref,
  level: level,
  source: source,
  dateState: dateState,
  learnedOn: dateState == DateState.beforeTracking ? null : learnedOn,
  stage: stage,
  recordedAt: engineAt(minutes),
  originalRecordedAt: originalMinutes == null
      ? null
      : engineAt(originalMinutes),
  actor: parentActor,
);

/// A `before_tracking` node event covering [node].
LearningEvent engineGround(int id, NodeEntry node, {int minutes = 0}) =>
    engineLearn(
      id,
      node.ref,
      level: node.level,
      dateState: DateState.beforeTracking,
      minutes: minutes,
    );

/// A `void` of the event with id `engineUlid(target)`.
LearningEvent engineVoid(int id, int target, {int minutes = 0}) =>
    LearningEvent.voidOf(
      id: engineUlid(id),
      targetId: engineUlid(target),
      recordedAt: engineAt(minutes),
      actor: parentActor,
    );

/// A `stage_definitions` doc with [stageOrder].
MainTrackConfigDoc engineStage(int stageOrder) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.stages,
  docId: '${engineCurriculum}_$stageOrder',
  curriculumId: engineCurriculum,
  fields: {'stage_order': stageOrder},
);

/// A `curriculum_scopes` doc selecting [fields].
MainTrackConfigDoc engineScope(Map<String, Object?> fields) =>
    MainTrackConfigDoc(
      collection: MainTrackConfigDoc.scope,
      docId: '${engineCurriculum}_scope',
      curriculumId: engineCurriculum,
      fields: fields,
    );

/// A main-track intent for [engineCurriculum].
MainTrackIntent engineIntent({
  MainTrackState state = MainTrackState.active,
  DateTime? endedAt,
  String? trackingStartRef,
  List<MainTrackConfigDoc> stages = const [],
  MainTrackConfigDoc? scope,
  String curriculumId = engineCurriculum,
}) => MainTrackIntent(
  curriculumId: curriculumId,
  track: MainTrack(curriculumId: curriculumId, state: state, endedAt: endedAt),
  program: trackingStartRef == null
      ? null
      : MainTrackProgram(
          curriculumId: curriculumId,
          trackingStartRef: trackingStartRef,
        ),
  stages: [
    for (final s in stages)
      MainTrackConfigDoc(
        collection: s.collection,
        docId: s.docId,
        curriculumId: curriculumId,
        fields: s.fields,
      ),
  ],
  scope: scope,
);

/// A `mainTrackProgram` change-log entry that set `tracking_start_ref` to
/// [ref] at [minutes].
ChangeLogEntry engineStartEntry(int id, String ref, {required int minutes}) =>
    ChangeLogEntry(
      id: engineUlid(id),
      entity: GovernedEntity.mainTrackProgram,
      entityId: engineCurriculum,
      actionId: engineUlid(id + 1),
      before: {'profile_programs/$engineCurriculum.tracking_start_ref': null},
      after: {'profile_programs/$engineCurriculum.tracking_start_ref': ref},
      at: engineAt(minutes),
      actor: parentActor,
    );

/// Engine inputs over the fixture corpus by default.
LearnerStateInputs engineInputs({
  List<LearningEvent> events = const [],
  Map<String, MainTrackIntent>? intents,
  Map<String, Corpus>? corpora,
  List<ChangeLogEntry> intentHistory = const [],
  List<SubTrack> subTracks = const [],
  LearnerSettingsHistory? settingsHistory,
  DateTime? nowUtc,
  Map<String, CurriculumGoals> goals = const {},
  Map<String, List<CalendarAssignment>> calendars = const {},
}) => LearnerStateInputs(
  events: events,
  subTracks: subTracks,
  mainTrackIntent: intents ?? {engineCurriculum: engineIntent()},
  goals: goals,
  intentHistory: intentHistory,
  settingsHistory: settingsHistory ?? c0SettingsHistory(),
  calendars: calendars,
  corpora: corpora ?? {engineCurriculum: mishnayosCorpus()},
  nowUtc: nowUtc ?? engineAt(10000),
);
