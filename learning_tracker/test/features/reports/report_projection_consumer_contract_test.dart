// DNI-516 (Story 5.1) AC-1 / AD-48: reports render the engine's
// `ReportProjection` and compute no total, count or velocity of their own.
//
// * A compile-time consumer renders every report figure from a
//   `ReportProjection` alone: if a figure ever needs another input, this
//   file stops compiling or its assertions fail.
// * Source guards keep engine internals out of report consumers and keep
//   the projection built only by the engine.
//
// Story 5.4 adds `ReportPdfBuilder`; it extends this file with a check
// that the builder takes only the projection as input (follow-up bead).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

/// A minimal report renderer: its only input is the projection.
List<String> _render(ReportProjection p) => [
  'distinct ${p.distinctLearnt}',
  'events ${p.totalEvents}',
  for (final s in p.sources.values)
    [
      '${s.kind.name} ${s.source}',
      '${s.events}/${s.distinctLeaves}',
      _velocity(s.velocity),
    ].join(' '),
  if (p.beforeTracking case final b?) 'before ${b.events}/${b.distinctLeaves}',
  for (final g in p.groups) ...[
    'group ${g.name} ${g.events}/${g.distinctLeaves}',
    for (final m in g.members)
      [
        '  ${m.label} ${m.status.name}',
        '${m.totals.events}/${m.totals.distinctLeaves}',
        _velocity(m.totals.velocity),
      ].join(' '),
  ],
  'all ${_velocity(p.allSources)}',
  'status ${p.projectionStatus?.name}',
];

String _velocity(ReportVelocity? v) {
  if (v == null) return '-';
  final trailing = v.tooEarly ? 'too early' : '${v.trailing!.leavesPerWeek}';
  return '${v.sinceTracking?.leavesPerWeek}/wk, 28d $trailing';
}

/// Engine internals a report consumer must not import: it would let it
/// recount events, leaves or velocity outside the engine (AD-48).
const _engineInternals = [
  'learner_state/counted_events.dart',
  'learner_state/learnt_set.dart',
  'learner_state/expand_ground.dart',
  'learner_state/projection.dart',
  'learner_state/learning_event.dart',
];

Iterable<File> _dartFiles(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

void main() {
  test('every report figure renders from the projection alone', () {
    final school = SubTrack(
      id: engineUlid(10),
      curriculumId: engineCurriculum,
      name: 'School',
      type: SubTrackType.schoolYear,
      academicYear: 2026,
      windowStart: '2026-09-01',
      windowEnd: '2027-06-30',
      ratePerWeek: 2,
      weeksPerYear: 40,
      learnsOnShabbos: false,
      ground: const [berakhot],
      lastChangeId: engineUlid(11),
    );
    final state = const LearnerStateEngine().run(
      engineInputs(
        subTracks: [school],
        events: [
          engineLearn(1, 'Mishnah Berakhot 1:1', stage: 1),
          engineLearn(2, 'Mishnah Berakhot 1:2', source: school.id),
          engineGround(3, peah),
        ],
      ),
    );
    final lines = _render(state[engineCurriculum]!.report);
    expect(lines, contains('distinct 4'));
    expect(lines, contains('events 4'));
    expect(lines, contains('group School 1/1'));
    expect(lines.any((l) => l.startsWith('  2026–27 active 1/1')), isTrue);
    expect(lines, contains('before 2/2'));
    expect(lines.last, 'status ${ProjectionStatus.tooEarly.name}');
  });

  test('report consumers import no engine internals', () {
    for (final file in [
      ..._dartFiles('lib/features/reports'),
      ..._dartFiles('lib/features/progress/presentation/reports'),
    ]) {
      final source = file.readAsStringSync();
      for (final internal in _engineInternals) {
        expect(
          source.contains(internal),
          isFalse,
          reason: '${file.path} imports $internal (AD-48)',
        );
      }
    }
  });

  test('only the engine builds the projection', () {
    for (final file in _dartFiles('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('lib/domain/learner_state/report_projection.dart') ||
          path.endsWith('lib/domain/learner_state/learner_state_engine.dart')) {
        continue;
      }
      expect(
        file.readAsStringSync().contains('deriveReportProjection('),
        isFalse,
        reason: '$path builds a report projection outside the engine',
      );
    }
  });

  test('no report metric is emitted as analytics (T4.1)', () {
    for (final file in [
      ..._dartFiles('lib/core/analytics'),
      File('lib/features/learning/domain/commands/learning_analytics.dart'),
    ]) {
      expect(
        file.readAsStringSync().contains('report_projection.dart'),
        isFalse,
        reason: '${file.path} reads the report projection',
      );
    }
  });
}
