// Story 5.2 (DNI-517) T1: the report view orders and labels the engine's
// projection rows and computes nothing of its own (AD-48).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';

LifetimeReportView _view(ReportProjection report) => LifetimeReportView(
  curriculumId: report.curriculumId,
  curricula: [report.curriculumId],
  report: report,
);

void main() {
  group('sourceRows (AC-3)', () {
    test('Home first, sub-tracks in roll-up order, Before tracking last', () {
      final rows = _view(fullReport()).sourceRows;
      expect(rows.map((r) => r.kind).toList(), [
        LifetimeReportSourceKind.home,
        LifetimeReportSourceKind.ongoing,
        LifetimeReportSourceKind.schoolYear,
        LifetimeReportSourceKind.schoolYear,
        LifetimeReportSourceKind.schoolYear,
        LifetimeReportSourceKind.beforeTracking,
      ]);
      expect(rows.map((r) => r.totals.source).toList(), [
        LearningEvent.sourceMain,
        rebbeId,
        school2024,
        school2025,
        school2026,
        reportBeforeTrackingKey,
      ]);
      expect(rows[1].name, 'Rebbe');
      expect(rows[2].line?.label, '2024–25');
    });

    test('every row is the projection totals object, unchanged', () {
      final report = fullReport();
      final rows = _view(report).sourceRows;
      for (final row in rows) {
        final expected = row.kind == LifetimeReportSourceKind.beforeTracking
            ? report.beforeTracking
            : report.sources[row.totals.source];
        expect(identical(row.totals, expected), isTrue);
      }
    });

    test('the rows cover every projection source exactly once, so their '
        'events add up to the Learning events total', () {
      final report = fullReport();
      final rows = _view(report).sourceRows;
      expect(rows, hasLength(report.sources.length + 1));
      expect(rows.fold<int>(0, (n, r) => n + r.events), report.totalEvents);
    });

    test('an unknown sub-track source is listed as unknown, not dropped', () {
      const ghost = '01J00000000000000000GHOST0';
      final report = ReportProjection(
        curriculumId: reportCurriculum,
        distinctLearnt: 3,
        totalEvents: 3,
        sources: {
          LearningEvent.sourceMain: reportTotals(
            LearningEvent.sourceMain,
            events: 0,
            distinct: 0,
          ),
          ghost: reportTotals(
            ghost,
            events: 3,
            distinct: 3,
            kind: ReportSourceKind.unknownSubTrack,
          ),
        },
      );
      final rows = _view(report).sourceRows;
      expect(rows.last.kind, LifetimeReportSourceKind.unknown);
      expect(rows.last.name, isNull);
    });

    test('a learner with no sub-tracks has Home and Before tracking only '
        '(AC-7)', () {
      final view = _view(homeOnlyReport());
      expect(view.sourceRows.map((r) => r.kind).toList(), [
        LifetimeReportSourceKind.home,
        LifetimeReportSourceKind.beforeTracking,
      ]);
      expect(view.groups, isEmpty);
    });
  });

  test('isEmpty follows the projection event total (AC-8)', () {
    expect(_view(ReportProjection.empty(reportCurriculum)).isEmpty, isTrue);
    expect(_view(homeOnlyReport()).isEmpty, isFalse);
  });

  test('curriculum resolves the app enum for labels', () {
    expect(_view(homeOnlyReport()).curriculum, CurriculumId.mishnayos);
  });

  test('orderCurricula uses the canonical order, unknown keys last', () {
    expect(LifetimeReportView.orderCurricula(['zzz', 'mishnayos', 'chumash']), [
      'chumash',
      'mishnayos',
      'zzz',
    ]);
  });
}
