// DNI-516 (Story 5.1): the report projection in the engine (AD-48, FR-30,
// FR-31, FR-32). Every case runs `LearnerStateEngine.run`: the projection
// is never built outside the engine.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
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
}
