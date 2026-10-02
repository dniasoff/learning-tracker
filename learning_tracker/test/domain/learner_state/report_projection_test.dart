// DNI-516 (Story 5.1): the report projection in the engine (AD-48, FR-30,
// FR-31, FR-32). Every case runs `LearnerStateEngine.run`: the projection
// is never built outside the engine.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';
const _b21 = 'Mishnah Berakhot 2:1';
const _b22 = 'Mishnah Berakhot 2:2';
const _p11 = 'Mishnah Peah 1:1';
const _p12 = 'Mishnah Peah 1:2';
const _s11 = 'Mishnah Shabbat 1:1';
const _s12 = 'Mishnah Shabbat 1:2';

const _allLeaves = [_b11, _b12, _b13, _b21, _b22, _p11, _p12, _s11, _s12];

/// The fixture learner is UTC with no location, so the fail-closed
/// Shabbos lock is Fri 2026-09-04 12:00Z → Sun 2026-09-06 01:00Z.
const _inLock = 6000;

SubTrack _sub(
  int id, {
  String name = 'School',
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String start = '2026-09-01',
  String? end,
  DateTime? endedAt,
  SubTrackEndReason? endReason,
  String curriculumId = engineCurriculum,
}) => SubTrack(
  id: engineUlid(id),
  curriculumId: curriculumId,
  name: name,
  type: type,
  academicYear: academicYear,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [berakhot],
  lastChangeId: engineUlid(id + 1),
  endedAt: endedAt,
  endReason: endReason,
);

LearnerState _state({
  List<LearningEvent> events = const [],
  List<SubTrack> subTracks = const [],
  MainTrackIntent? intent,
  DateTime? nowUtc,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    subTracks: subTracks,
    intents: {engineCurriculum: intent ?? engineIntent()},
    nowUtc: nowUtc,
  ),
);

ReportProjection _report({
  List<LearningEvent> events = const [],
  List<SubTrack> subTracks = const [],
  MainTrackIntent? intent,
  DateTime? nowUtc,
}) => _state(
  events: events,
  subTracks: subTracks,
  intent: intent,
  nowUtc: nowUtc,
)[engineCurriculum]!.report;

/// The FR-30 per-leaf count of counted events (no lock-ignored event in
/// the logs this is used on), summed over the corpus.
int _historyCountSum(LearnerState state, List<LearningEvent> events) {
  final corpus = mishnayosCorpus();
  var sum = 0;
  for (final leaf in _allLeaves) {
    for (final e in events) {
      if (!state.countedEventIds.contains(e.id)) continue;
      if (e.ref == leaf) {
        sum++;
      } else if (e.level != null &&
          corpus.leavesUnder(corpus.nodeForRef(e.ref!)!).contains(leaf)) {
        sum++;
      }
    }
  }
  return sum;
}

/// Velocity fixtures: today is Thursday 2026-10-08 (no lock); every event
/// is recorded then (10:00Z) and `learned_on` carries its day.
final _vNow = DateTime.utc(2026, 10, 8, 12);
const _vToday = '2026-10-08';
final _vRecorded = DateTime.utc(
  2026,
  10,
  8,
  10,
).difference(DateTime.utc(2026, 9)).inMinutes;

/// [offset] days after [_vToday] (negative: before).
String _vDay(int offset) => shiftCivilDate(_vToday, offset);

LearningEvent _on(
  int id,
  String ref,
  String day, {
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  int? stage,
  int? recordedMinutes,
}) => engineLearn(
  id,
  ref,
  minutes: recordedMinutes ?? _vRecorded,
  learnedOn: day,
  source: source,
  dateState: dateState,
  stage: stage,
);

MainTrackIntent _tracked(
  String? trackingStartDate, {
  MainTrackState state = MainTrackState.active,
}) => MainTrackIntent(
  curriculumId: engineCurriculum,
  track: MainTrack(curriculumId: engineCurriculum, state: state),
  program: trackingStartDate == null
      ? null
      : MainTrackProgram(
          curriculumId: engineCurriculum,
          trackingStartDate: trackingStartDate,
        ),
);

CurriculumState _vRun(
  List<LearningEvent> events, {
  String? trackingStartDate = '2026-09-01',
  List<SubTrack> subTracks = const [],
  DeadlineGoal? deadline,
  MainTrackState state = MainTrackState.active,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    subTracks: subTracks,
    nowUtc: _vNow,
    intents: {engineCurriculum: _tracked(trackingStartDate, state: state)},
    goals: {engineCurriculum: CurriculumGoals(deadline: deadline)},
  ),
)[engineCurriculum]!;

/// Every report number of [r], for golden comparison.
Map<String, Object?> _golden(ReportProjection r) => {
  'distinct': r.distinctLearnt,
  'events': r.totalEvents,
  'sources': {
    for (final s in r.sources.values) s.source: [s.events, s.distinctLeaves],
  },
  'before': r.beforeTracking == null
      ? null
      : [r.beforeTracking!.events, r.beforeTracking!.distinctLeaves],
  'groups': {
    for (final g in r.groups)
      g.name: [
        g.events,
        g.distinctLeaves,
        [for (final m in g.members) '${m.label} ${m.status.name}'],
      ],
  },
  'since/wk': r.allSources?.sinceTracking?.leavesPerWeek,
  '28d/wk': r.allSources?.trailing?.leavesPerWeek,
  'status': r.projectionStatus,
};

void main() {
  group('AC-1: the engine builds a pure per-curriculum projection', () {
    test('every curriculum with a corpus has a report', () {
      final state = _state(events: [engineLearn(1, _b11, stage: 1)]);
      final report = state[engineCurriculum]!.report;
      expect(report.curriculumId, engineCurriculum);
      expect(report.distinctLearnt, 1);
      expect(report.totalEvents, 1);
      expect(report.home.events, 1);
    });

    test('identical inputs give equal projections', () {
      final events = [
        engineLearn(1, _b11, stage: 1),
        engineLearn(2, _b11, stage: 2),
        engineGround(3, berakhot2),
      ];
      expect(_report(events: events), _report(events: events));
    });

    // `tool/check_dependency_direction.dart` (run by learner_state_test
    // and as a story gate) covers every lib/domain file; this pins the
    // stricter rule that the projection depends on engine code only.
    test('report_projection.dart imports only pure domain code', () {
      final source = File(
        'lib/domain/learner_state/report_projection.dart',
      ).readAsStringSync();
      final imports = RegExp(
        "^import '([^']+)';",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!);
      for (final uri in imports) {
        expect(
          uri,
          startsWith('package:learning_tracker/domain/learner_state/'),
          reason: 'no Flutter, Riverpod, Firestore or data import: $uri',
        );
      }
    });
  });

  group('AC-2: distinct leaves and expanded event count', () {
    final events = [
      engineLearn(1, _b11, stage: 1),
      engineLearn(2, _b11, stage: 2),
      engineLearn(3, _p11, dateState: DateState.catchUp),
      // Berakhot perek 2: two leaves, two events.
      engineGround(4, berakhot2),
      // Overlaps 1:1 already learnt dated.
      engineLearn(5, _b11, dateState: DateState.beforeTracking),
    ];

    test('distinct learnt equals the engine learnt set size', () {
      final state = _state(events: events);
      final c = state[engineCurriculum]!;
      expect(c.report.distinctLearnt, c.learntLeaves.length);
      expect(c.report.distinctLearnt, c.distinctLearnt);
      expect(c.report.distinctLearnt, 4);
    });

    test('total events is the sum of per-leaf counted history; a node '
        'before_tracking event counts once per covered leaf', () {
      final state = _state(events: events);
      final report = state[engineCurriculum]!.report;
      // 1:1 ×3, Peah 1:1 ×1, perek 2 ×2.
      expect(report.totalEvents, 6);
      expect(report.totalEvents, _historyCountSum(state, events));
    });

    test('per-source totals and the bucket partition the events', () {
      final report = _report(events: events);
      expect(report.home.events, 3);
      expect(report.home.leaves, {_b11, _p11});
      expect(report.beforeTracking!.events, 3);
      expect(report.beforeTracking!.leaves, {_b11, _b21, _b22});
      expect(report.beforeTracking!.kind, ReportSourceKind.beforeTracking);
      expect(
        report.sources.values.fold<int>(0, (n, s) => n + s.events) +
            report.beforeTracking!.events,
        report.totalEvents,
      );
    });

    test('an event outside the learner corpus counts nowhere', () {
      final report = _report(
        events: [
          engineLearn(1, _b11, stage: 1),
          engineLearn(2, 'Mishnah Unknown 9:9', stage: 1),
        ],
      );
      expect(report.totalEvents, 1);
      expect(report.distinctLearnt, 1);
    });
  });

  group('AC-3: void, lock and undo replay', () {
    test('a voided event contributes nowhere', () {
      final report = _report(
        events: [
          engineLearn(1, _b11, stage: 1),
          engineLearn(2, _b12, stage: 1),
          engineVoid(3, 2, minutes: 5),
        ],
      );
      expect(report.totalEvents, 1);
      expect(report.distinctLearnt, 1);
      expect(report.home.leaves, {_b11});
    });

    test('a lock-ignored event contributes nowhere', () {
      final state = _state(
        events: [
          engineLearn(1, _b11, stage: 1),
          engineLearn(2, _b12, stage: 1, minutes: _inLock),
        ],
      );
      expect(state.lockIgnoredEventIds, {engineUlid(2)});
      final report = state[engineCurriculum]!.report;
      expect(report.totalEvents, 1);
      expect(report.home.leaves, {_b11});
    });

    test('undo of a void (a re-copy with original_recorded_at) restores '
        'the contribution', () {
      final before = _report(events: [engineLearn(1, _b12, stage: 1)]);
      final restored = _report(
        events: [
          engineLearn(1, _b12, stage: 1),
          engineVoid(2, 1, minutes: 10),
          engineLearn(3, _b12, stage: 1, minutes: 20, originalMinutes: 0),
        ],
      );
      expect(restored.totalEvents, before.totalEvents);
      expect(restored.distinctLearnt, before.distinctLearnt);
      expect(restored.home.leaves, before.home.leaves);
    });
  });

  test('AC-4: totals keep growing after the goal completes; distinct '
      'stays at the corpus size', () {
    final everything = [
      for (final (i, leaf) in _allLeaves.indexed)
        engineLearn(i + 1, leaf, stage: 1),
    ];
    final complete = _report(events: everything);
    expect(complete.distinctLearnt, _allLeaves.length);
    final more = _report(
      events: [
        ...everything,
        engineLearn(100, _b11, stage: 2, minutes: 50),
        engineLearn(101, _b11, stage: 2, minutes: 60),
      ],
    );
    expect(more.distinctLearnt, _allLeaves.length);
    expect(more.totalEvents, complete.totalEvents + 2);
    expect(more.home.events, complete.home.events + 2);
  });

  group('AC-8: no sub-tracks', () {
    test('Home only, plus the Before-tracking bucket when present', () {
      final report = _report(
        events: [engineLearn(1, _b11, stage: 1), engineGround(2, peah)],
      );
      expect(report.sources.keys, [LearningEvent.sourceMain]);
      expect(report.beforeTracking, isNotNull);
    });

    test('no bucket without before_tracking events', () {
      final report = _report(events: [engineLearn(1, _b11, stage: 1)]);
      expect(report.sources.keys, [LearningEvent.sourceMain]);
      expect(report.beforeTracking, isNull);
    });

    test('an empty profile reports zero Home totals', () {
      final report = _report();
      expect(report.distinctLearnt, 0);
      expect(report.totalEvents, 0);
      expect(report.sources.keys, [LearningEvent.sourceMain]);
      expect(report.home.events, 0);
      expect(report.beforeTracking, isNull);
    });
  });

  test('a sub-track source is keyed by its ULID; a ULID with no doc is '
      'kept as an unknown source', () {
    final school = _sub(10);
    final report = _report(
      subTracks: [school],
      events: [
        engineLearn(1, _b11, source: school.id),
        engineLearn(2, _b12, source: engineUlid(50)),
      ],
    );
    expect(report.sources[school.id]!.kind, ReportSourceKind.subTrack);
    expect(report.sources[school.id]!.events, 1);
    final unknown = report.sources[engineUlid(50)]!;
    expect(unknown.kind, ReportSourceKind.unknownSubTrack);
    expect(unknown.leaves, {_b12});
    expect(report.totalEvents, 2);
  });

  group('AC-5: normalized groups and member lines', () {
    final y2024 = _sub(
      10,
      type: SubTrackType.schoolYear,
      academicYear: 2024,
      start: '2024-09-01',
      end: '2025-06-30',
    );
    final y2025 = _sub(
      20,
      type: SubTrackType.schoolYear,
      academicYear: 2025,
      start: '2025-09-01',
      end: '2026-06-30',
    );
    final y2026 = _sub(
      30,
      name: 'school ',
      type: SubTrackType.schoolYear,
      academicYear: 2026,
      start: '2026-09-01',
      end: '2027-06-30',
    );
    final summer = _sub(40, name: 'SCHOOL', start: '2026-07-01');
    final rebbe = _sub(50, name: 'Rebbe');
    final events = [
      engineLearn(1, _b11, source: y2024.id),
      engineLearn(2, _b12, source: y2024.id),
      // 1:1 again in another year: two events, one group leaf.
      engineLearn(3, _b11, source: y2025.id),
      engineLearn(4, _b13, source: y2026.id),
      engineLearn(5, _b21, source: summer.id),
      engineLearn(6, _p11, source: rebbe.id),
    ];
    final report = _report(
      subTracks: [y2026, rebbe, summer, y2025, y2024],
      events: events,
    );

    test('trimmed, case-folded names form one group', () {
      expect(report.groups.map((g) => g.key), ['rebbe', 'school']);
      final school = report.groups.last;
      expect(school.members.map((m) => m.subTrackId), [
        y2024.id,
        y2025.id,
        summer.id,
        y2026.id,
      ]);
      // The latest member names the group, trimmed.
      expect(school.name, 'school');
    });

    test('group events add up; group distinct leaves are a union', () {
      final school = report.groups.last;
      expect(school.events, 5);
      expect(
        school.events,
        school.members.fold<int>(0, (n, m) => n + m.totals.events),
      );
      expect(school.leaves, {_b11, _b12, _b13, _b21});
      expect(school.distinctLeaves, 4);
      expect(
        school.members.fold<int>(0, (n, m) => n + m.totals.distinctLeaves),
        5,
      );
    });

    test('year lines are keyed by academic_year and labelled YYYY–YY', () {
      final lines = report.groups.last.members;
      expect(lines[0].academicYear, 2024);
      expect(lines[0].label, '2024–25');
      expect(lines[1].label, '2025–26');
      expect(lines[3].label, '2026–27');
      expect(reportSchoolYearLabel(2099), '2099–00');
    });

    test('an ongoing member is labelled by its stored window', () {
      final line = report.groups.last.members[2];
      expect(line.type, SubTrackType.ongoing);
      expect(line.academicYear, isNull);
      expect(line.label, '2026-07-01 –');
      expect(
        reportWindowLabel('2026-07-01', '2026-08-31'),
        '2026-07-01 – 2026-08-31',
      );
    });

    test('every member is also a per-source total', () {
      for (final line in report.groups.expand((g) => g.members)) {
        expect(report.sources[line.subTrackId], same(line.totals));
      }
      expect(report.sources.keys.first, LearningEvent.sourceMain);
      expect(report.sources, hasLength(6));
    });

    test('a sub-track with no events is listed at zero', () {
      final idle = _report(subTracks: [rebbe]);
      expect(idle.groups.single.members.single.totals.events, 0);
      expect(idle.sources[rebbe.id]!.events, 0);
    });
  });

  group('AC-6: ended and deleted sources stay reportable', () {
    final deleted = _sub(
      10,
      name: 'Shiur',
      endedAt: engineAt(3000),
      endReason: SubTrackEndReason.deleted,
    );
    final trackDeleted = _sub(
      20,
      name: 'Chavrusa',
      endedAt: engineAt(3000),
      endReason: SubTrackEndReason.trackDeleted,
    );
    final ended = _sub(
      30,
      name: 'Camp',
      endedAt: engineAt(3000),
      endReason: SubTrackEndReason.ended,
    );
    final live = _sub(40, name: 'Rebbe');
    final events = [
      engineLearn(1, _b11, source: deleted.id),
      engineLearn(2, _b12, source: trackDeleted.id),
      engineLearn(3, _b13, source: ended.id),
      engineLearn(4, _b21, source: live.id),
    ];
    final report = _report(
      subTracks: [deleted, trackDeleted, ended, live],
      events: events,
    );

    test('their events stay in every total', () {
      expect(report.totalEvents, 4);
      expect(report.distinctLearnt, 4);
      expect(report.sources[deleted.id]!.events, 1);
      expect(report.sources[trackDeleted.id]!.events, 1);
    });

    test('listed under the stored name and marked Ended', () {
      final byKey = {for (final g in report.groups) g.key: g};
      expect(byKey.keys, containsAll(['shiur', 'chavrusa', 'camp']));
      for (final key in ['shiur', 'chavrusa', 'camp']) {
        final line = byKey[key]!.members.single;
        expect(line.status, ReportLineStatus.ended);
        expect(line.endedOn, '2026-09-03');
      }
      expect(byKey['shiur']!.name, 'Shiur');
      expect(
        byKey['shiur']!.members.single.endReason,
        SubTrackEndReason.deleted,
      );
      expect(byKey['rebbe']!.members.single.status, ReportLineStatus.active);
    });

    test('unfinished ground is never reported completed; a live track '
        'with all ground ticked is still active', () {
      final finished = _sub(50, name: 'Done');
      final r = _report(
        subTracks: [finished],
        events: [
          for (final (i, leaf) in [_b11, _b12, _b13, _b21, _b22].indexed)
            engineLearn(i + 1, leaf, source: finished.id),
        ],
      );
      expect(r.groups.single.members.single.status, ReportLineStatus.active);
      expect(ReportLineStatus.values.map((s) => s.name), ['active', 'ended']);
    });

    test('an undone creation with no events is not listed', () {
      final undone = _sub(
        60,
        name: 'Oops',
        endedAt: engineAt(10),
        endReason: SubTrackEndReason.undo,
      );
      final r = _report(subTracks: [undone]);
      expect(r.groups, isEmpty);
      expect(r.sources.keys, [LearningEvent.sourceMain]);
    });
  });

  test('AC-7: after a rename every event of the sub-track groups under its '
      'current name', () {
    final renamed = _sub(10, name: 'Morning seder');
    final report = _report(
      subTracks: [renamed],
      events: [
        // Recorded while it was still called "School".
        engineLearn(1, _b11, source: renamed.id),
        engineLearn(2, _b12, source: renamed.id, minutes: 3000),
      ],
    );
    expect(report.groups, hasLength(1));
    final group = report.groups.single;
    expect(group.key, 'morning seder');
    expect(group.name, 'Morning seder');
    expect(group.events, 2);
    expect(group.members.single.name, 'Morning seder');
  });

  group('AC-9: per-source and all-source velocity', () {
    test('a source counts the leaves it first learnt; all-sources counts '
        'each leaf once, on its first day overall', () {
      final school = _sub(10, start: '2026-09-01');
      final c = _vRun(
        subTracks: [school],
        [
          _on(1, _b11, _vDay(-5)),
          // School learns 1:1 after Home did: it counts for School too.
          _on(2, _b11, _vDay(-3), source: school.id),
          _on(3, _b12, _vDay(-3), source: school.id),
        ],
      );
      final report = c.report;
      expect(report.home.velocity!.trailing!.leaves, 1);
      expect(report.sources[school.id]!.velocity!.trailing!.leaves, 2);
      expect(report.allSources!.trailing!.leaves, 2);
      // Per-source figures may add up to more than all-sources.
      expect(
        report.home.velocity!.trailing!.leaves +
            report.sources[school.id]!.velocity!.trailing!.leaves,
        greaterThan(report.allSources!.trailing!.leaves),
      );
    });

    test('a source\'s first event counts even after its own repeat', () {
      final c = _vRun([
        _on(1, _b11, _vDay(-10), stage: 1),
        _on(2, _b11, _vDay(-2), stage: 2),
        _on(3, _b12, _vDay(-2), stage: 2),
      ]);
      // 1:1 once (stage 1); 1:2 only as chazara (stage 2): not new.
      expect(c.report.home.velocity!.trailing!.leaves, 1);
      expect(c.report.allSources!.trailing!.leaves, 1);
    });

    test('before_tracking never contributes to any velocity', () {
      final school = _sub(10);
      final c = _vRun(
        subTracks: [school],
        [
          engineGround(1, peah),
          _on(2, _p11, _vDay(-2), source: school.id),
          _on(3, _p12, _vDay(-2)),
          _on(4, _b11, _vDay(-2)),
        ],
      );
      final report = c.report;
      expect(report.beforeTracking!.velocity, isNull);
      expect(report.sources[school.id]!.velocity!.trailing!.leaves, 0);
      expect(report.home.velocity!.trailing!.leaves, 1);
      expect(report.allSources!.trailing!.leaves, 1);
      // Its events still count in the totals.
      expect(report.sources[school.id]!.events, 1);
    });

    test('a catch_up event counts on learned_on, not on recorded_at', () {
      // Recorded today; learned 28 days ago (just outside the trailing
      // window, which starts 27 days ago) and 27 days ago (inside).
      final c = _vRun([
        _on(1, _b11, _vDay(-28), dateState: DateState.catchUp),
        _on(2, _b12, _vDay(-27), dateState: DateState.catchUp),
      ]);
      final trailing = c.report.allSources!.trailing!;
      expect(trailing.from, _vDay(-27));
      expect(trailing.through, _vToday);
      expect(trailing.days, 28);
      expect(trailing.leaves, 1);
      expect(c.report.home.velocity!.trailing!.leaves, 1);
      // Since tracking (2026-09-01) both count.
      expect(c.report.home.velocity!.sinceTracking!.leaves, 2);
    });

    test('since-tracking span: tracking start through today, as leaves '
        'per week to one decimal', () {
      final c = _vRun([
        _on(1, _b11, '2026-09-01'),
        _on(2, _b12, '2026-09-15'),
        _on(3, _b13, _vToday),
      ]);
      final since = c.report.home.velocity!.sinceTracking!;
      expect(since.from, '2026-09-01');
      expect(since.through, _vToday);
      expect(since.days, 38);
      expect(since.leaves, 3);
      // 3 × 7 ÷ 38 = 0.5526… → 0.6.
      expect(since.leavesPerWeek, 0.6);
      expect(since.leavesPerDay, 3 / 38);
    });

    test('a later sub-track window_start starts its span; an ended '
        'sub-track\'s span stops at its ended_at day', () {
      final late = _sub(10, name: 'Late', start: '2026-09-20');
      final early = _sub(20, name: 'Early', start: '2026-08-01');
      final ended = _sub(
        30,
        name: 'Ended',
        start: '2026-09-01',
        endedAt: DateTime.utc(2026, 10, 1, 9),
        endReason: SubTrackEndReason.deleted,
      );
      final c = _vRun(
        subTracks: [late, early, ended],
        [
          _on(1, _b11, '2026-09-25', source: late.id),
          _on(2, _b12, '2026-09-05', source: early.id),
          _on(3, _b13, '2026-09-30', source: ended.id),
        ],
      );
      final lateV = c.report.sources[late.id]!.velocity!;
      expect(lateV.sinceTracking!.from, '2026-09-20');
      expect(lateV.sinceTracking!.days, 19);
      expect(lateV.trailing!.from, '2026-09-20');
      final earlyV = c.report.sources[early.id]!.velocity!;
      expect(earlyV.sinceTracking!.from, '2026-09-01');
      final endedV = c.report.sources[ended.id]!.velocity!;
      expect(endedV.sinceTracking!.through, '2026-10-01');
      expect(endedV.sinceTracking!.days, 31);
      expect(endedV.trailing!.through, '2026-10-01');
      expect(endedV.trailing!.from, '2026-09-04');
      expect(endedV.trailing!.leaves, 1);
    });

    test('a future sub-track has no span yet', () {
      final future = _sub(10, start: '2026-11-01');
      final v = _vRun(
        subTracks: [future],
        const [],
      ).report.sources[future.id]!.velocity!;
      expect(v.sinceTracking, isNull);
      expect(v.tooEarly, isTrue);
    });

    group('trailing window thresholds (28; 14–27 all; under 14 too early)', () {
      ReportVelocity homeFrom(String start) => _vRun(trackingStartDate: start, [
        _on(1, _b11, _vToday),
      ]).report.home.velocity!;

      test('13 days: too early to tell', () {
        final v = homeFrom(_vDay(-12));
        expect(v.tooEarly, isTrue);
        expect(v.sinceTracking!.days, 13);
      });

      test('14 days: all of the history', () {
        final v = homeFrom(_vDay(-13));
        expect(v.trailing!.days, 14);
        expect(v.trailing!.from, _vDay(-13));
        // 1 × 7 ÷ 14 = 0.5.
        expect(v.trailing!.leavesPerWeek, 0.5);
      });

      test('27 days: all of the history', () {
        expect(homeFrom(_vDay(-26)).trailing!.days, 27);
      });

      test('28 days and more: the trailing 28 days', () {
        expect(homeFrom(_vDay(-27)).trailing!.days, 28);
        final v = homeFrom(_vDay(-100));
        expect(v.trailing!.days, 28);
        expect(v.trailing!.from, _vDay(-27));
        // 1 × 7 ÷ 28 = 0.25 → 0.3.
        expect(v.trailing!.leavesPerWeek, 0.3);
      });

      test('a sub-track uses the same rule over its own span', () {
        final recent = _sub(10, start: _vDay(-5));
        final v = _vRun(
          subTracks: [recent],
          [_on(1, _b11, _vToday, source: recent.id)],
        ).report.sources[recent.id]!.velocity!;
        expect(v.tooEarly, isTrue);
        expect(v.sinceTracking!.days, 6);
      });
    });

    test('the all-sources trailing velocity is the engine projection '
        'velocity exactly', () {
      final school = _sub(10);
      final c = _vRun(
        subTracks: [school],
        deadline: const DeadlineGoal(
          curriculumId: engineCurriculum,
          targetDate: '2026-12-31',
        ),
        [
          engineGround(1, peah),
          _on(2, _b11, _vDay(-40), stage: 1),
          _on(3, _b12, _vDay(-20), stage: 1),
          _on(4, _b12, _vDay(-10), stage: 2),
          _on(5, _b13, _vDay(-3), source: school.id),
          _on(6, _b21, _vDay(-1), dateState: DateState.catchUp),
          _on(7, _p11, _vDay(-1)),
        ],
      );
      final projection = c.projection!;
      expect(projection.velocityPerDay, isNotNull);
      expect(
        c.report.allSources!.trailing!.leavesPerDay,
        projection.velocityPerDay,
      );
      expect(c.report.allSources!.trailing!.leaves, 3);
      expect(c.report.projectionStatus, projection.status);
      expect(c.report.projectionStatus, isNot(ProjectionStatus.noDeadline));
    });

    test('too early for the projection is too early for the report', () {
      final c = _vRun(trackingStartDate: _vDay(-3), [_on(1, _b11, _vToday)]);
      expect(c.projection!.status, ProjectionStatus.tooEarly);
      expect(c.report.allSources!.tooEarly, isTrue);
      expect(c.report.projectionStatus, ProjectionStatus.tooEarly);
    });

    test('a curriculum that is not evaluated has totals but no velocity '
        'or status', () {
      final school = _sub(10);
      final c = _vRun(
        subTracks: [school],
        state: MainTrackState.retired,
        [_on(1, _b11, _vDay(-2)), _on(2, _b12, _vDay(-2), source: school.id)],
      );
      expect(c.evaluated, isFalse);
      expect(c.report.totalEvents, 2);
      expect(c.report.groups.single.events, 1);
      expect(c.report.allSources, isNull);
      expect(c.report.projectionStatus, isNull);
      expect(c.report.home.velocity, isNull);
      expect(c.report.sources[school.id]!.velocity, isNull);
    });
  });

  group('AC-10: golden numbers', () {
    test('empty profile', () {
      expect(_golden(_vRun(const []).report), {
        'distinct': 0,
        'events': 0,
        'sources': {
          LearningEvent.sourceMain: [0, 0],
        },
        'before': null,
        'groups': <String, Object?>{},
        'since/wk': 0.0,
        '28d/wk': 0.0,
        'status': ProjectionStatus.noDeadline,
      });
    });

    test('single source', () {
      final report = _vRun([
        _on(1, _b11, _vDay(-30), stage: 1),
        _on(2, _b12, _vDay(-20), stage: 1),
        _on(3, _b11, _vDay(-10), stage: 2),
        _on(4, _b13, _vDay(-1), stage: 1),
      ]).report;
      expect(_golden(report), {
        'distinct': 3,
        'events': 4,
        'sources': {
          LearningEvent.sourceMain: [4, 3],
        },
        'before': null,
        'groups': <String, Object?>{},
        // 3 × 7 ÷ 38 = 0.55 → 0.6; 2 × 7 ÷ 28 = 0.5.
        'since/wk': 0.6,
        '28d/wk': 0.5,
        'status': ProjectionStatus.noDeadline,
      });
    });

    test('multiple sources', () {
      final school = _sub(10);
      final rebbe = _sub(20, name: 'Rebbe');
      final report = _vRun(
        subTracks: [school, rebbe],
        [
          _on(1, _b11, _vDay(-5)),
          _on(2, _b11, _vDay(-3), source: school.id),
          _on(3, _b12, _vDay(-3), source: school.id),
          _on(4, _p11, _vDay(-2), source: rebbe.id),
        ],
      ).report;
      expect(_golden(report), {
        'distinct': 3,
        'events': 4,
        'sources': {
          LearningEvent.sourceMain: [1, 1],
          school.id: [2, 2],
          rebbe.id: [1, 1],
        },
        'before': null,
        'groups': {
          'Rebbe': [
            1,
            1,
            ['2026-09-01 – active'],
          ],
          'School': [
            2,
            2,
            ['2026-09-01 – active'],
          ],
        },
        // 3 × 7 ÷ 38 = 0.55 → 0.6; 3 × 7 ÷ 28 = 0.75 → 0.8.
        'since/wk': 0.6,
        '28d/wk': 0.8,
        'status': ProjectionStatus.noDeadline,
      });
      expect(report.home.velocity!.trailing!.leavesPerWeek, 0.3);
      expect(report.sources[school.id]!.velocity!.trailing!.leavesPerWeek, 0.5);
    });

    test('a void and a re-copy', () {
      final report = _vRun([
        _on(1, _b11, _vDay(-3)),
        engineVoid(2, 1, minutes: _vRecorded + 1),
        // Undo of the void: a re-copy keeping the original instant.
        engineLearn(
          3,
          _b11,
          minutes: _vRecorded + 2,
          originalMinutes: _vRecorded,
          learnedOn: _vDay(-3),
        ),
        _on(4, _b12, _vDay(-3)),
        engineVoid(5, 4, minutes: _vRecorded + 3),
      ]).report;
      expect(_golden(report), {
        'distinct': 1,
        'events': 1,
        'sources': {
          LearningEvent.sourceMain: [1, 1],
        },
        'before': null,
        'groups': <String, Object?>{},
        // 1 × 7 ÷ 38 = 0.18 → 0.2; 1 × 7 ÷ 28 = 0.25 → 0.3.
        'since/wk': 0.2,
        '28d/wk': 0.3,
        'status': ProjectionStatus.noDeadline,
      });
      expect(report.home.velocity!.trailing!.leaves, 1);
    });

    test('a lock-ignored event', () {
      // Recorded Shabbos 2026-10-03 10:00Z, inside the fail-closed lock.
      final inLock = DateTime.utc(
        2026,
        10,
        3,
        10,
      ).difference(DateTime.utc(2026, 9)).inMinutes;
      final state = const LearnerStateEngine().run(
        engineInputs(
          nowUtc: _vNow,
          intents: {engineCurriculum: _tracked('2026-09-01')},
          events: [
            _on(1, _b11, _vDay(-6)),
            _on(2, _b12, _vDay(-5), recordedMinutes: inLock),
          ],
        ),
      );
      expect(state.lockIgnoredEventIds, {engineUlid(2)});
      expect(_golden(state[engineCurriculum]!.report), {
        'distinct': 1,
        'events': 1,
        'sources': {
          LearningEvent.sourceMain: [1, 1],
        },
        'before': null,
        'groups': <String, Object?>{},
        'since/wk': 0.2,
        '28d/wk': 0.3,
        'status': ProjectionStatus.noDeadline,
      });
    });

    test('a catch-up crossing a week boundary', () {
      // Learnt Thu 2026-09-10 and Fri 2026-09-11, recorded weeks later on
      // Thu 2026-10-08: the trailing window starts on 2026-09-11.
      final report = _vRun([
        _on(1, _b11, '2026-09-10', dateState: DateState.catchUp),
        _on(2, _b12, '2026-09-11', dateState: DateState.catchUp),
      ]).report;
      expect(report.allSources!.trailing!.from, '2026-09-11');
      expect(_golden(report), {
        'distinct': 2,
        'events': 2,
        'sources': {
          LearningEvent.sourceMain: [2, 2],
        },
        'before': null,
        'groups': <String, Object?>{},
        // 2 × 7 ÷ 38 = 0.37 → 0.4; 1 × 7 ÷ 28 = 0.25 → 0.3.
        'since/wk': 0.4,
        '28d/wk': 0.3,
        'status': ProjectionStatus.noDeadline,
      });
    });

    test('a before-tracking node event', () {
      final report = _vRun([
        engineGround(1, peah),
        _on(2, _b11, _vDay(-2)),
      ]).report;
      expect(_golden(report), {
        'distinct': 3,
        'events': 3,
        'sources': {
          LearningEvent.sourceMain: [1, 1],
        },
        'before': [2, 2],
        'groups': <String, Object?>{},
        'since/wk': 0.2,
        '28d/wk': 0.3,
        'status': ProjectionStatus.noDeadline,
      });
    });

    test('a renamed track', () {
      final renamed = _sub(
        10,
        name: 'Morning seder',
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        end: '2027-06-30',
      );
      final report = _vRun(
        subTracks: [renamed],
        [
          _on(1, _b11, _vDay(-20), source: renamed.id),
          _on(2, _b12, _vDay(-2), source: renamed.id),
        ],
      ).report;
      expect(_golden(report), {
        'distinct': 2,
        'events': 2,
        'sources': {
          LearningEvent.sourceMain: [0, 0],
          renamed.id: [2, 2],
        },
        'before': null,
        'groups': {
          'Morning seder': [
            2,
            2,
            ['2026–27 active'],
          ],
        },
        'since/wk': 0.4,
        '28d/wk': 0.5,
        'status': ProjectionStatus.noDeadline,
      });
    });

    test('a deleted track', () {
      final deleted = _sub(
        10,
        name: 'Shiur',
        endedAt: DateTime.utc(2026, 10, 1, 9),
        endReason: SubTrackEndReason.deleted,
      );
      final report = _vRun(
        subTracks: [deleted],
        [
          _on(1, _b11, _vDay(-10), source: deleted.id),
          _on(2, _b12, _vDay(-9), source: deleted.id),
        ],
      ).report;
      expect(_golden(report), {
        'distinct': 2,
        'events': 2,
        'sources': {
          LearningEvent.sourceMain: [0, 0],
          deleted.id: [2, 2],
        },
        'before': null,
        'groups': {
          'Shiur': [
            2,
            2,
            ['2026-09-01 – ended'],
          ],
        },
        'since/wk': 0.4,
        '28d/wk': 0.5,
        'status': ProjectionStatus.noDeadline,
      });
      // Its own span stops on 2026-10-01: 31 days, trailing 28.
      final v = report.sources[deleted.id]!.velocity!;
      expect(v.sinceTracking!.days, 31);
      expect(v.trailing!.through, '2026-10-01');
      expect(v.trailing!.leavesPerWeek, 0.5);
    });

    test('a retired curriculum', () {
      final school = _sub(10);
      final report = _vRun(
        state: MainTrackState.retired,
        subTracks: [school],
        [
          _on(1, _b11, _vDay(-10)),
          _on(2, _b11, _vDay(-9)),
          _on(3, _b12, _vDay(-9), source: school.id),
          engineGround(4, berakhot2),
        ],
      ).report;
      expect(_golden(report), {
        'distinct': 4,
        'events': 5,
        'sources': {
          LearningEvent.sourceMain: [2, 1],
          school.id: [1, 1],
        },
        'before': [2, 2],
        'groups': {
          'School': [
            1,
            1,
            ['2026-09-01 – active'],
          ],
        },
        'since/wk': null,
        '28d/wk': null,
        'status': null,
      });
    });
  });
}
