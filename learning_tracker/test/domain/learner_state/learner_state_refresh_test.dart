// DNI-494 (Story 2.3) AC-7: every local-cache change listed by the AC —
// main-track order, ground add / reorder / remove, a rate, a window, a
// return, a new learn and a void — recomputes the FR-19 target from the
// complete inputs. The engine keeps no state between runs and persists no
// summary, so the next run over the changed inputs is the new answer.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/bundled_corpus.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

// Today is Thursday 2026-10-01 and the deadline Wednesday 2026-10-07.
// Only Thursday is a study day, so studyDaysToDeadline = 1 and the daily
// target equals the numerator: every change shows in the target exactly.
final _now = DateTime.utc(2026, 10, 1, 12);
final _rebbeId = engineUlid(601);

NodeEntry _perek(String masechta, int n) =>
    NodeEntry(level: 'chapter', ref: 'Mishnah $masechta $n');

final _b2 = _perek('Berakhot', 2);
final _b4 = _perek('Berakhot', 4);
final _b6 = _perek('Berakhot', 6);
final _b8 = _perek('Berakhot', 8);
final _p2 = _perek('Peah', 2);
final _p3 = _perek('Peah', 3);

/// Rebbe: ongoing from 2026-10-01, 20/wk, 52 weeks: capacity to
/// 2026-10-07 is floor(20 × 52 × 7 ÷ 365) = 19.
SubTrack _rebbe({
  List<NodeEntry>? ground,
  double rate = 20,
  String windowStart = '2026-10-01',
  bool ended = false,
}) => SubTrack(
  id: _rebbeId,
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: windowStart,
  ratePerWeek: rate,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: ground ?? [_b2, _b6, _b8, _p2, _p3],
  lastChangeId: engineUlid(700),
  endedAt: ended ? engineAt(1) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

MainTrackConfigDoc _day(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

MainTrackOrderEntry _order(String seder, int sort) => MainTrackOrderEntry(
  docId: '${engineCurriculum}_seder_$seder',
  curriculumId: engineCurriculum,
  level: 'seder',
  ref: seder,
  userSortOrder: sort,
  lastChangeId: engineUlid(900),
);

/// The local cache: the complete engine inputs as they stand.
final class _Cache {
  _Cache({required this.subTracks, required this.events});

  List<SubTrack> subTracks;
  List<LearningEvent> events;
  List<MainTrackOrderEntry> order = const [];

  LearnerStateInputs get inputs => engineInputs(
    nowUtc: _now,
    events: events,
    subTracks: subTracks,
    corpora: {engineCurriculum: bundledCorpus(engineCurriculum)},
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        order: order,
        studyDays: [
          _day(4, 'study'),
          for (final dow in [1, 2, 3, 5, 6, 7]) _day(dow, 'review'),
        ],
      ),
    },
    goals: {
      engineCurriculum: const CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: engineCurriculum,
          targetDate: '2026-10-07',
        ),
      ),
    },
  );

  CurriculumState run() =>
      const LearnerStateEngine().run(inputs)[engineCurriculum]!;
}

void main() {
  final corpus = bundledCorpus(engineCurriculum);
  var nextId = 1;

  /// Dated main-track learns of every leaf of [node], recorded on
  /// Wednesday 2026-09-30.
  List<LearningEvent> learnAll(NodeEntry node) => [
    for (final leaf in corpus.leavesUnder(node))
      engineLearn(
        nextId++,
        leaf,
        minutes: 29 * 1440 + 600,
        learnedOn: '2026-09-30',
        stage: 1,
      ),
  ];

  late _Cache cache;
  late List<LearningEvent> b4Learns;

  setUp(() {
    nextId = 1;
    b4Learns = learnAll(_b4);
    // Berakhot 2 (ground, inside the Rebbe's reach) and Berakhot 4 (main
    // track) are learnt.
    cache = _Cache(
      subTracks: [_rebbe()],
      events: [...learnAll(_b2), ...b4Learns],
    );
  });

  test('baseline: 4,145 main-track leaves + 21 shortfall', () {
    final s = cache.run();
    expect(s.mainTrackRemaining, 4192 - 40 - 7);
    expect(s.subTracks[_rebbeId]!.capacity, 19);
    expect(s.shortfall, 21);
    expect(s.dailyTarget, 4166);
  });

  test('main-track order: recomputed schedulable order, same count', () {
    final before = cache.run();
    expect(before.schedulableRefs.first, 'Mishnah Berakhot 1:1');
    cache.order = [_order('Seder Moed', 0), _order('Seder Zeraim', 1)];
    final after = cache.run();
    expect(
      after.schedulableRefs.first,
      corpus
          .leavesUnder(const NodeEntry(level: 'seder', ref: 'Seder Moed'))
          .first,
    );
    expect(after.dailyTarget, before.dailyTarget);
  });

  test('ground add: a learnt perek in front uses capacity', () {
    // Path B4 (7 learnt), B2 (8 learnt), B6 …: reach 19 leaves 4 of B6, so
    // the shortfall is 4 + 8 + 8 + 8 = 28; B4 was already off the main
    // track (learnt).
    cache.subTracks = [
      _rebbe(ground: [_b4, _b2, _b6, _b8, _p2, _p3]),
    ];
    final s = cache.run();
    expect(s.mainTrackRemaining, 4145);
    expect(s.shortfall, 28);
    expect(s.dailyTarget, 4173);
  });

  test('ground reorder: learnt leaves moved past the reach free capacity', () {
    cache.subTracks = [
      _rebbe(ground: [_b6, _b8, _p2, _p3, _b2]),
    ];
    final s = cache.run();
    // Reach 19 = B6 (8) + B8 (8) + Peah 2:1–2:3: shortfall 5 + 8 = 13.
    expect(s.shortfall, 13);
    expect(s.dailyTarget, 4158);
  });

  test('ground remove: dropping the learnt perek frees capacity', () {
    cache.subTracks = [
      _rebbe(ground: [_b6, _b8, _p2, _p3]),
    ];
    final s = cache.run();
    expect(s.mainTrackRemaining, 4145);
    expect(s.shortfall, 13);
    expect(s.dailyTarget, 4158);
  });

  test('rate: doubling the rate reaches all but one leaf', () {
    // floor(40 × 52 × 7 ÷ 365) = 39.
    cache.subTracks = [_rebbe(rate: 40)];
    final s = cache.run();
    expect(s.subTracks[_rebbeId]!.capacity, 39);
    expect(s.shortfall, 1);
    expect(s.dailyTarget, 4146);
  });

  test('window: a later window_start shrinks capacity', () {
    // [2026-10-05, 2026-10-07] = 3 days: floor(20 × 52 × 3 ÷ 365) = 8,
    // all of it on learnt Berakhot 2.
    cache.subTracks = [_rebbe(windowStart: '2026-10-05')];
    final s = cache.run();
    expect(s.subTracks[_rebbeId]!.capacity, 8);
    expect(s.shortfall, 32);
    expect(s.dailyTarget, 4177);
  });

  test('return: an ended sub-track gives its ground back', () {
    cache.subTracks = [_rebbe(ended: true)];
    final s = cache.run();
    expect(s.mainTrackRemaining, 4192 - 8 - 7);
    expect(s.shortfall, 0);
    expect(s.dailyTarget, 4177);
  });

  test('new learn: a shortfall leaf learnt drops out', () {
    cache.events = [
      ...cache.events,
      engineLearn(
        5000,
        'Mishnah Peah 3:1',
        minutes: 29 * 1440 + 660,
        learnedOn: '2026-09-30',
        stage: 1,
      ),
    ];
    final s = cache.run();
    expect(s.shortfall, 20);
    expect(s.dailyTarget, 4165);
  });

  test('void: a voided main-track learn comes back', () {
    final target = b4Learns.first;
    cache.events = [
      ...cache.events,
      LearningEvent.voidOf(
        id: engineUlid(5001),
        targetId: target.id,
        recordedAt: engineAt(29 * 1440 + 700),
        actor: target.actor,
      ),
    ];
    final s = cache.run();
    expect(s.mainTrackRemaining, 4146);
    expect(s.dailyTarget, 4167);
  });

  test('no state survives between runs: the same inputs give the same '
      'state, before and after other runs', () {
    final first = cache.run();
    cache.subTracks = [_rebbe(rate: 40)];
    cache.run();
    cache.subTracks = [_rebbe()];
    final again = cache.run();
    expect(again.dailyTarget, first.dailyTarget);
    expect(again.subTracks, first.subTracks);
  });
}
