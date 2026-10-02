// DNI-494 (Story 2.3) AC-1, AC-2, AC-3, AC-8 and edge cases: AD-44
// sub-track capacity, expected new ground, shortfall and the FR-19 daily
// target, with exact fixture values over the real ContentIndex Mishnayos
// corpus (4,192 leaves).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_capacity.dart';

import '../../helpers/learner_state/bundled_corpus.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _today = '2026-10-01';

/// Noon UTC on [day] (the fixture learner's zone is UTC).
DateTime _noon(CivilDate day) => DateTime.parse('${day}T12:00:00Z');

NodeEntry _perek(String masechta, int n) =>
    NodeEntry(level: 'chapter', ref: 'Mishnah $masechta $n');

final _rebbeId = engineUlid(601);
final _shiurId = engineUlid(602);
final _schoolId = engineUlid(603);

/// The Rebbe's 40 ground leaves: five 8-mishna perakim, in ContentIndex
/// order.
final _rebbeGround = [
  _perek('Berakhot', 2),
  _perek('Berakhot', 6),
  _perek('Berakhot', 8),
  _perek('Peah', 2),
  _perek('Peah', 3),
];

SubTrack _track(
  String id, {
  SubTrackType type = SubTrackType.ongoing,
  required CivilDate windowStart,
  CivilDate? windowEnd,
  required double ratePerWeek,
  required double weeksPerYear,
  List<NodeEntry> ground = const [],
  String name = 'Track',
}) => SubTrack(
  id: id,
  curriculumId: engineCurriculum,
  name: name,
  type: type,
  academicYear: type == SubTrackType.schoolYear ? 2026 : null,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: ratePerWeek,
  weeksPerYear: weeksPerYear,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(700),
);

/// Rebbe: ongoing, 2/wk, 52 weeks, from 2026-10-01, open end.
SubTrack _rebbe({List<NodeEntry>? ground}) => _track(
  _rebbeId,
  name: 'Rebbe',
  windowStart: '2026-10-01',
  ratePerWeek: 2,
  weeksPerYear: 52,
  ground: ground ?? _rebbeGround,
);

/// Shiur: ongoing, 1/wk, 52 weeks, from 2026-10-01, open end. Capacity to
/// 2026-12-09 is floor(1 × 52 × 70 ÷ 365) = 9.
SubTrack _shiur(List<NodeEntry> ground) => _track(
  _shiurId,
  name: 'Shiur',
  windowStart: '2026-10-01',
  ratePerWeek: 1,
  weeksPerYear: 52,
  ground: ground,
);

/// School: school-year 2026 (2026-09-01 .. 2027-07-31), 10/wk, 39 weeks.
SubTrack _school({List<NodeEntry> ground = const []}) => _track(
  _schoolId,
  name: 'School',
  type: SubTrackType.schoolYear,
  windowStart: '2026-09-01',
  windowEnd: '2027-07-31',
  ratePerWeek: 10,
  weeksPerYear: 39,
  ground: ground,
);

DeadlineGoal _deadline(CivilDate target) =>
    DeadlineGoal(curriculumId: engineCurriculum, targetDate: target);

/// A dated main-track learn of [ref], recorded on Wednesday 2026-09-02.
LearningEvent _learnt(int id, String ref) => engineLearn(
  id,
  ref,
  minutes: 1440 + 600,
  learnedOn: '2026-09-02',
  stage: 1,
);

MainTrackConfigDoc _day(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

CurriculumState _run({
  required List<SubTrack> subTracks,
  CivilDate target = '2026-12-09',
  CivilDate today = _today,
  List<LearningEvent> events = const [],
  bool bundled = true,
  List<MainTrackConfigDoc> studyDays = const [],
  MainTrackProgram? program,
  bool withDeadline = true,
}) => const LearnerStateEngine().run(
  engineInputs(
    nowUtc: _noon(today),
    events: events,
    subTracks: subTracks,
    corpora: bundled
        ? {engineCurriculum: bundledCorpus(engineCurriculum)}
        : null,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        studyDays: studyDays,
        program: program,
      ),
    },
    goals: {
      engineCurriculum: CurriculumGoals(
        deadline: withDeadline ? _deadline(target) : null,
      ),
    },
  ),
)[engineCurriculum]!;

/// `Σ expectedNewGround` over the curriculum's sub-tracks.
int _expected(CurriculumState s) =>
    s.subTracks.values.fold(0, (sum, t) => sum + t.expectedNewGround);

/// `Σ shortfall` over the curriculum's sub-tracks.
int _shortfall(CurriculumState s) =>
    s.subTracks.values.fold(0, (sum, t) => sum + t.shortfall);

/// The FR-19 numerator the engine divided.
int _numerator(CurriculumState s) =>
    s.mainTrackRemaining - _expected(s) + _shortfall(s);

void _expectTrack(
  CurriculumState s,
  String id, {
  required int capacity,
  required int expectedNewGround,
  required int shortfall,
}) {
  final t = s.subTracks[id]!;
  expect(
    (t.capacity, t.expectedNewGround, t.shortfall),
    (capacity, expectedNewGround, shortfall),
    reason: 'capacity, expectedNewGround, shortfall of $id',
  );
}

void main() {
  final corpus = bundledCorpus(engineCurriculum);
  final berakhot1to3 = [
    for (final n in [1, 2, 3]) ...corpus.leavesUnder(_perek('Berakhot', n)),
  ];

  test('the bundled corpus is the full ContentIndex Mishnayos', () {
    expect(corpus.leaves, hasLength(4192));
    expect(berakhot1to3, hasLength(19));
  });

  group('AC-1: AD-44 capacity arithmetic', () {
    test('days([a, b]) is inclusive and 0 when reversed', () {
      expect(civilDays('2026-10-01', '2026-12-09'), 70);
      expect(civilDays('2026-12-09', '2026-12-09'), 1);
      expect(civilDays('2026-12-10', '2026-12-09'), 0);
    });

    test('school-year prorates over days([window_start, window_end]), '
        'ongoing over 365', () {
      expect(windowLengthDays(_school()), 334);
      expect(windowLengthDays(_rebbe()), 365);
      // School to 2029-03-14: [2026-10-01, 2027-07-31] = 304 days.
      expect(
        activeWeeksLeft(_school(), today: _today, targetDate: '2029-03-14'),
        39 * 304 / 334,
      );
      expect(
        subTrackCapacity(_school(), today: _today, targetDate: '2029-03-14'),
        354,
      );
      expect(
        subTrackCapacity(_rebbe(), today: _today, targetDate: '2026-12-09'),
        19,
      );
    });

    test('an exact integer product floors to itself', () {
      // A whole school year left: 10 × 39 × 334 ÷ 334 = 390.
      expect(
        subTrackCapacity(
          _school(),
          today: '2026-09-01',
          targetDate: '2029-03-14',
        ),
        390,
      );
    });

    test('the target divides the numerator by the inclusive study days', () {
      final s = _run(subTracks: [_rebbe()]);
      // mainTrackRemaining 4152, expected 0, shortfall 21: 4173 ÷ 70.
      expect(s.mainTrackRemaining, 4152);
      expect(_numerator(s), 4173);
      expect(s.dailyTarget, 60);
    });

    test('only configured study days divide', () {
      // Monday–Thursday study: [2026-10-01 Thu, 2026-12-09 Wed] has 40;
      // ceil(4173 ÷ 40) = 105.
      final s = _run(
        subTracks: [_rebbe()],
        studyDays: [
          for (final dow in [1, 2, 3, 4]) _day(dow, 'study'),
          for (final dow in [5, 6, 7]) _day(dow, 'review'),
        ],
      );
      expect(s.dailyTarget, 105);
    });
  });

  group('AC-2: FR-19 groundless School, then ground entered', () {
    const target = '2029-03-14';
    // [2026-10-01, 2029-03-14] = 896 study days (all seven).
    final ground = [
      for (final n in [1, 2, 3]) _perek('Berakhot', n),
    ];

    test('entering unlearnt ground leaves the target unchanged', () {
      final before = _run(subTracks: [_school()], target: target);
      final after = _run(
        subTracks: [_school(ground: ground)],
        target: target,
      );
      _expectTrack(
        before,
        _schoolId,
        capacity: 354,
        expectedNewGround: 354,
        shortfall: 0,
      );
      _expectTrack(
        after,
        _schoolId,
        capacity: 354,
        expectedNewGround: 354 - 19,
        shortfall: 0,
      );
      expect(before.mainTrackRemaining, 4192);
      expect(before.mainTrackRemaining - after.mainTrackRemaining, 19);
      expect(_expected(before) - _expected(after), 19);
      expect(_numerator(before), 3838);
      expect(_numerator(after), 3838);
      expect(before.dailyTarget, 5);
      expect(after.dailyTarget, before.dailyTarget);
    });

    test('k already-learnt ground leaves: remaining drops by n − k and the '
        'target rises (chazara on the path uses capacity)', () {
      const k = 5;
      // 250 other learnt leaves put the numerator just under 4 × 896, so
      // the k-leaf rise shows in the ceiling.
      final others = corpus.leaves
          .where((l) => !berakhot1to3.contains(l))
          .take(250)
          .toList();
      final events = [
        for (final (i, leaf) in berakhot1to3.take(k).indexed)
          _learnt(i + 1, leaf),
        for (final (i, leaf) in others.indexed) _learnt(100 + i, leaf),
      ];
      final before = _run(
        subTracks: [_school()],
        target: target,
        events: events,
      );
      final after = _run(
        subTracks: [_school(ground: ground)],
        target: target,
        events: events,
      );
      expect(before.mainTrackRemaining - after.mainTrackRemaining, 19 - k);
      expect(_expected(before) - _expected(after), 19);
      expect(after.subTracks[_schoolId]!.capacity, 354);
      expect(_numerator(after) - _numerator(before), k);
      expect(_numerator(before), 3583);
      expect(before.dailyTarget, 4);
      expect(after.dailyTarget, 5);
    });
  });

  group('AC-3: fixture matrix (today 2026-10-01, deadline 2026-12-09, '
      '70 study days)', () {
    test('shortfall: capacity 19 over 40 unlearnt leaves', () {
      final s = _run(subTracks: [_rebbe()]);
      _expectTrack(
        s,
        _rebbeId,
        capacity: 19,
        expectedNewGround: 0,
        shortfall: 21,
      );
      expect(s.shortfall, 21);
      expect(s.dailyTarget, 60);
    });

    test('overlapping shortfall on two tracks is counted once', () {
      // Shiur path: Peah 4 (11) then Peah 3 (8); capacity 9 reaches 4:1–4:9.
      // Peah 3 is shortfall on both: counted once, under the Rebbe
      // (lower ULID).
      final s = _run(
        subTracks: [
          _rebbe(),
          _shiur([_perek('Peah', 4), _perek('Peah', 3)]),
        ],
      );
      _expectTrack(
        s,
        _rebbeId,
        capacity: 19,
        expectedNewGround: 0,
        shortfall: 21,
      );
      _expectTrack(
        s,
        _shiurId,
        capacity: 9,
        expectedNewGround: 0,
        shortfall: 2,
      );
      expect(s.shortfall, 23);
      // 4192 − 51 held leaves = 4141; + 23 = 4164.
      expect(s.mainTrackRemaining, 4141);
      expect(_numerator(s), 4164);
      expect(s.dailyTarget, 60);
    });

    test('a leaf another holder reaches within capacity is not shortfall', () {
      final s = _run(
        subTracks: [
          _rebbe(),
          _shiur([_perek('Peah', 3)]),
        ],
      );
      _expectTrack(
        s,
        _rebbeId,
        capacity: 19,
        expectedNewGround: 0,
        shortfall: 13,
      );
      _expectTrack(
        s,
        _shiurId,
        capacity: 9,
        expectedNewGround: 1,
        shortfall: 0,
      );
      expect(s.mainTrackRemaining, 4152);
      expect(_numerator(s), 4152 - 1 + 13);
      expect(s.dailyTarget, 60);
    });

    test("two tracks' expected new ground both count in full, even over "
        'shared ground', () {
      // School to 2026-12-09: floor(10 × 39 × 70 ÷ 334) = 81.
      final berakhot1 = [_perek('Berakhot', 1)];
      final s = _run(
        subTracks: [
          _school(ground: berakhot1),
          _shiur(berakhot1),
        ],
      );
      _expectTrack(
        s,
        _schoolId,
        capacity: 81,
        expectedNewGround: 76,
        shortfall: 0,
      );
      _expectTrack(
        s,
        _shiurId,
        capacity: 9,
        expectedNewGround: 4,
        shortfall: 0,
      );
      expect(s.mainTrackRemaining, 4187);
      expect(_numerator(s), 4187 - 80);
      expect(s.dailyTarget, 59);
    });

    test('a groundless track: the whole capacity is expected new ground', () {
      final s = _run(subTracks: [_school()]);
      _expectTrack(
        s,
        _schoolId,
        capacity: 81,
        expectedNewGround: 81,
        shortfall: 0,
      );
      expect(_numerator(s), 4111);
      expect(s.dailyTarget, 59);
    });

    test('a part-elapsed school year is prorated', () {
      // Today 2027-03-01: [2027-03-01, 2027-07-31] = 153 of 334 days;
      // floor(10 × 39 × 153 ÷ 334) = 178. 745 study days to 2029-03-14.
      final s = _run(
        subTracks: [_school()],
        today: '2027-03-01',
        target: '2029-03-14',
      );
      _expectTrack(
        s,
        _schoolId,
        capacity: 178,
        expectedNewGround: 178,
        shortfall: 0,
      );
      expect(s.dailyTarget, (4014 / 745).ceil());
      expect(s.dailyTarget, 6);
    });

    test('a future-start ongoing track counts from window_start', () {
      // [2026-11-01, 2026-12-09] = 39 days: floor(2 × 52 × 39 ÷ 365) = 11.
      final future = _track(
        _rebbeId,
        windowStart: '2026-11-01',
        ratePerWeek: 2,
        weeksPerYear: 52,
      );
      final s = _run(subTracks: [future]);
      expect(s.subTracks[_rebbeId]!.holdsGround, isTrue);
      _expectTrack(
        s,
        _rebbeId,
        capacity: 11,
        expectedNewGround: 11,
        shortfall: 0,
      );
      expect(s.dailyTarget, 60);
    });

    test('a window crossing the deadline is capped at target_date', () {
      // window_end 2027-06-30 would give 273 days (capacity 77); capped at
      // 2026-12-09 it is 70 days, the same as an open end.
      final crossing = _track(
        _rebbeId,
        windowStart: '2026-09-01',
        windowEnd: '2027-06-30',
        ratePerWeek: 2,
        weeksPerYear: 52,
        ground: _rebbeGround,
      );
      final s = _run(subTracks: [crossing]);
      _expectTrack(
        s,
        _rebbeId,
        capacity: 19,
        expectedNewGround: 0,
        shortfall: 21,
      );
      final school = _run(subTracks: [_school()], target: '2027-03-01');
      // School capped at 2027-03-01: [2026-10-01, 2027-03-01] = 152 days.
      expect(
        school.subTracks[_schoolId]!.capacity,
        (10 * 39 * 152 / 334).floor(),
      );
    });

    test('a numerator at or below 0 gives a target of 0', () {
      // The 9-leaf fixture corpus against School's 81.
      final s = _run(subTracks: [_school()], bundled: false);
      expect(_numerator(s), 9 - 81);
      expect(s.dailyTarget, 0);
    });

    test('no study day left gives the numerator', () {
      // Thursday 2026-10-01 is a review day and the deadline: 0 study
      // days. The Rebbe's one-day interval gives floor(2 × 52 ÷ 365) = 0,
      // so all 40 ground leaves come back.
      final s = _run(
        subTracks: [_rebbe()],
        target: _today,
        studyDays: [
          _day(4, 'review'),
          for (final dow in [1, 2, 3, 5, 6, 7]) _day(dow, 'study'),
        ],
      );
      _expectTrack(
        s,
        _rebbeId,
        capacity: 0,
        expectedNewGround: 0,
        shortfall: 40,
      );
      expect(_numerator(s), 4192);
      expect(s.dailyTarget, 4192);
    });

    test('B13 default: no study day left and a negative numerator gives 0', () {
      final big = _track(
        _schoolId,
        windowStart: _today,
        ratePerWeek: 1000,
        weeksPerYear: 52,
      );
      final s = _run(
        subTracks: [big],
        bundled: false,
        target: _today,
        studyDays: [
          _day(4, 'review'),
          for (final dow in [1, 2, 3, 5, 6, 7]) _day(dow, 'study'),
        ],
      );
      // floor(1000 × 52 × 1 ÷ 365) = 142 > 9 leaves.
      expect(_numerator(s), 9 - 142);
      expect(s.dailyTarget, 0);
    });
  });

  group('edge cases', () {
    test('an empty capacity interval gives capacity 0: all unlearnt ground '
        'comes back', () {
      final late = _track(
        _rebbeId,
        windowStart: '2027-01-01',
        ratePerWeek: 2,
        weeksPerYear: 52,
        ground: _rebbeGround,
      );
      expect(
        subTrackCapacity(late, today: _today, targetDate: '2026-12-09'),
        0,
      );
      final s = _run(subTracks: [late]);
      expect(s.subTracks[_rebbeId]!.inForecast, isFalse);
      _expectTrack(
        s,
        _rebbeId,
        capacity: 0,
        expectedNewGround: 0,
        shortfall: 40,
      );
    });

    test('an inclusive one-day interval is not empty', () {
      final oneDay = _track(
        _rebbeId,
        windowStart: '2026-12-09',
        ratePerWeek: 100,
        weeksPerYear: 52,
      );
      // floor(100 × 52 × 1 ÷ 365) = 14.
      expect(
        subTrackCapacity(oneDay, today: _today, targetDate: '2026-12-09'),
        14,
      );
    });

    test('already-learnt path leaves consume capacity but are never '
        'shortfall', () {
      // Learnt inside reach (Berakhot 2): no change to the shortfall.
      final inReach = _run(
        subTracks: [_rebbe()],
        events: [
          for (final (i, leaf)
              in corpus.leavesUnder(_perek('Berakhot', 2)).take(5).indexed)
            _learnt(i + 1, leaf),
        ],
      );
      expect(inReach.subTracks[_rebbeId]!.shortfall, 21);
      // Learnt beyond reach (Peah 3): those 5 drop out of the shortfall.
      final beyond = _run(
        subTracks: [_rebbe()],
        events: [
          for (final (i, leaf)
              in corpus.leavesUnder(_perek('Peah', 3)).take(5).indexed)
            _learnt(i + 1, leaf),
        ],
      );
      expect(beyond.subTracks[_rebbeId]!.shortfall, 16);
    });

    test('a sub-track that does not hold ground is not forecast', () {
      final ended = SubTrack(
        id: _shiurId,
        curriculumId: engineCurriculum,
        name: 'Old',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 50,
        weeksPerYear: 52,
        learnsOnShabbos: false,
        ground: [_perek('Peah', 3)],
        lastChangeId: engineUlid(700),
        endedAt: engineAt(1),
        endReason: SubTrackEndReason.ended,
      );
      final s = _run(subTracks: [_rebbe(), ended]);
      expect(s.subTracks[_shiurId]!.capacity, isNull);
      expect(s.subTracks[_shiurId]!.expectedNewGround, 0);
      // The ended track holds nothing, so it cannot reach Peah 3.
      expect(s.subTracks[_rebbeId]!.shortfall, 21);
    });

    test('identical inputs give equal states', () {
      expect(
        _run(subTracks: [_rebbe(), _school()]),
        _run(subTracks: [_rebbe(), _school()]),
      );
    });
  });

  group('AC-4: per-sub-track shortfall output for FR-21', () {
    List<String> leaves(String masechta, int perek, {int from = 1}) => [
      for (final l in corpus.leavesUnder(_perek(masechta, perek)))
        if (int.parse(l.split(':').last) >= from) l,
    ];

    test('count, leaves in path order, window end and last ground node', () {
      final s = _run(subTracks: [_rebbe(), _school()]);
      final rebbe = s.subTracks[_rebbeId]!;
      expect(rebbe.shortfallLeaves, [
        ...leaves('Berakhot', 8, from: 4),
        ...leaves('Peah', 2),
        ...leaves('Peah', 3),
      ]);
      expect(rebbe.shortfall, rebbe.shortfallLeaves.length);
      expect(rebbe.windowEnd, isNull);
      expect(rebbe.lastShortfallNode, _perek('Peah', 3));
      final school = s.subTracks[_schoolId]!;
      expect(school.windowEnd, '2027-07-31');
      expect(school.shortfallLeaves, isEmpty);
      expect(school.lastShortfallNode, isNull);
      // The curriculum shortfall is the FR-19 term the target divided.
      expect(s.shortfall, 21);
      expect(_numerator(s), s.mainTrackRemaining - 81 + 21);
    });

    test('path order follows ground as entered, not ContentIndex order', () {
      final s = _run(
        subTracks: [
          _rebbe(
            ground: [
              _perek('Peah', 3),
              _perek('Berakhot', 6),
              _perek('Berakhot', 2),
              _perek('Peah', 2),
              _perek('Berakhot', 8),
            ],
          ),
        ],
      );
      final rebbe = s.subTracks[_rebbeId]!;
      expect(rebbe.shortfallLeaves, [
        ...leaves('Berakhot', 2, from: 4),
        ...leaves('Peah', 2),
        ...leaves('Berakhot', 8),
      ]);
      expect(rebbe.lastShortfallNode, _perek('Berakhot', 8));
    });

    test('the last node is the last entry that still has a shortfall leaf', () {
      // The Shiur reaches Peah 3, so the Rebbe's last shortfall entry is
      // Peah 2.
      final s = _run(
        subTracks: [
          _rebbe(),
          _shiur([_perek('Peah', 3)]),
        ],
      );
      final rebbe = s.subTracks[_rebbeId]!;
      expect(rebbe.shortfallLeaves, [
        ...leaves('Berakhot', 8, from: 4),
        ...leaves('Peah', 2),
      ]);
      expect(rebbe.lastShortfallNode, _perek('Peah', 2));
    });

    test('an overlapping shortfall leaf belongs to one track only, so the '
        'per-track counts sum to the FR-19 term', () {
      final s = _run(
        subTracks: [
          _rebbe(),
          _shiur([_perek('Peah', 4), _perek('Peah', 3)]),
        ],
      );
      final rebbe = s.subTracks[_rebbeId]!;
      final shiur = s.subTracks[_shiurId]!;
      expect(shiur.shortfallLeaves, leaves('Peah', 4, from: 10));
      expect(shiur.lastShortfallNode, _perek('Peah', 4));
      expect(
        rebbe.shortfallLeaves.toSet().intersection(
          shiur.shortfallLeaves.toSet(),
        ),
        isEmpty,
      );
      expect(rebbe.shortfall + shiur.shortfall, s.shortfall);
    });

    test('with no deadline nothing is exposed but the window end', () {
      final s = _run(subTracks: [_rebbe(), _school()], withDeadline: false);
      for (final t in s.subTracks.values) {
        expect(t.capacity, isNull);
        expect(t.shortfall, 0);
        expect(t.shortfallLeaves, isEmpty);
        expect(t.lastShortfallNode, isNull);
      }
      expect(s.subTracks[_schoolId]!.windowEnd, '2027-07-31');
      expect(s.shortfall, isNull);
    });
  });

  group('AC-8: calendar-program curriculum', () {
    test('AD-44 is not computed; dailyTarget comes from the calendar', () {
      final s = const LearnerStateEngine().run(
        engineInputs(
          nowUtc: _noon(_today),
          subTracks: [
            _rebbe(ground: [berakhot1]),
          ],
          intents: {
            engineCurriculum: MainTrackIntent(
              curriculumId: engineCurriculum,
              track: MainTrack(
                curriculumId: engineCurriculum,
                state: MainTrackState.active,
              ),
              program: MainTrackProgram(
                curriculumId: engineCurriculum,
                programId: 'mishnah_yomit',
                trackingStartDate: '2026-09-28',
              ),
            ),
          },
          calendars: {
            'mishnah_yomit': [
              const CalendarAssignment(
                '2026-09-30',
                NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 2:1'),
              ),
              const CalendarAssignment(_today, peah),
            ],
          },
          goals: {
            engineCurriculum: CurriculumGoals(
              deadline: _deadline('2026-12-09'),
            ),
          },
        ),
      )[engineCurriculum]!;
      final rebbe = s.subTracks[_rebbeId]!;
      expect(rebbe.capacity, isNull);
      expect(rebbe.expectedNewGround, 0);
      expect(rebbe.shortfall, 0);
      // Assigned through today (2:1 + Peah's 2 leaves) minus learnt.
      expect(s.dailyTarget, 3);
      expect(s.shortfall, 1);
    });
  });
}
