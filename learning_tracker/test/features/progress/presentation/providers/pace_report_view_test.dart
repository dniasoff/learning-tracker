// Story 5.3 (DNI-518): the Per-source pace and On-track view selects the
// engine's values unchanged; it computes no velocity, status or shortfall.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';

LifetimeReportView _view(ReportProjection report) => LifetimeReportView(
  curriculumId: reportCurriculum,
  curricula: const [reportCurriculum],
  report: report,
);

void main() {
  group('rows (AC-1, AC-5, AC-8)', () {
    test('Home, then each sub-track in By-source order; no Before-tracking '
        'row; each velocity is the projection object itself', () {
      final report = paceReport(ended2025: true);
      final pace = PaceReportView.of(
        _view(report),
        paceCurriculumState(report),
      )!;
      expect([for (final r in pace.rows) r.source], [
        LearningEvent.sourceMain,
        rebbeId,
        school2025,
        school2026,
      ]);
      for (final row in pace.rows) {
        expect(
          identical(row.velocity, report.sources[row.source]!.velocity),
          isTrue,
        );
      }
    });

    test('active sub-tracks carry their stored estimate; Home has none',
        () {
      final report = paceReport();
      final pace = PaceReportView.of(
        _view(report),
        paceCurriculumState(report),
      )!;
      final bySource = {for (final r in pace.rows) r.source: r};
      expect(bySource[LearningEvent.sourceMain]!.estimatePerWeek, isNull);
      expect(bySource[school2026]!.estimatePerWeek, 10);
      expect(bySource[rebbeId]!.estimatePerWeek, 5);
      expect(bySource[school2026]!.ended, isFalse);
    });

    for (final deleted in [false, true]) {
      test('an ${deleted ? 'deleted' : 'ended'} sub-track is Ended with no '
          'estimate', () {
        final report = paceReport(
          ended2025: !deleted,
          deleted2025: deleted,
        );
        final pace = PaceReportView.of(
          _view(report),
          paceCurriculumState(report),
        )!;
        final row = pace.rows.firstWhere((r) => r.source == school2025);
        expect(row.ended, isTrue);
        expect(row.estimatePerWeek, isNull);
        expect(row.velocity.sinceTracking!.through, '2026-09-20');
      });
    }

    test('a sub-track ULID with no doc is Ended with no estimate', () {
      final report = paceReport(unknownSource: true);
      final pace = PaceReportView.of(
        _view(report),
        paceCurriculumState(report),
      )!;
      final row = pace.rows.last;
      expect(row.kind, LifetimeReportSourceKind.unknown);
      expect(row.ended, isTrue);
      expect(row.estimatePerWeek, isNull);
    });

    test('a calendar program has the Home row only (AC-8)', () {
      final report = paceReport(calendarProgram: true);
      final pace = PaceReportView.of(
        _view(report),
        paceCurriculumState(report, shortfall: 4, subTracks: const {}),
      )!;
      expect(pace.calendarProgram, isTrue);
      expect([for (final r in pace.rows) r.source], [
        LearningEvent.sourceMain,
      ]);
    });
  });

  group('not evaluated (AC-9)', () {
    test('no pace view for a retired or archived curriculum', () {
      final report = paceReport();
      expect(
        PaceReportView.of(
          _view(report),
          paceCurriculumState(report, evaluated: false),
        ),
        isNull,
      );
    });

    test('no pace view without a curriculum state or without engine '
        'velocity', () {
      expect(PaceReportView.of(_view(paceReport()), null), isNull);
      final noVelocity = homeOnlyReport();
      expect(
        PaceReportView.of(
          _view(noVelocity),
          paceCurriculumState(noVelocity),
        ),
        isNull,
      );
    });
  });

  group('on-track block (AC-6, AC-7, AC-8)', () {
    OnTrackView onTrack(
      ProjectionStatus status, {
      int? dailyTarget = 3,
      bool calendar = false,
      int? shortfall,
      Map<String, SubTrackState>? subTracks,
    }) {
      final report = paceReport(status: status, calendarProgram: calendar);
      return PaceReportView.of(
        _view(report),
        paceCurriculumState(
          report,
          dailyTarget: dailyTarget,
          shortfall: shortfall,
          subTracks:
              subTracks ??
              const {
                school2026: paceSchoolShortfall,
                rebbeId: paceRebbeNoShortfall,
              },
        ),
      )!.onTrack!;
    }

    test('the engine status, finish and daily target, unchanged', () {
      final on = onTrack(ProjectionStatus.onTrack);
      expect(on.status, PaceReportStatus.onTrack);
      expect(on.projectedFinish, '2029-03-14');
      expect(on.dailyTarget, 3);

      final behind = onTrack(ProjectionStatus.behindPace, dailyTarget: 7);
      expect(behind.status, PaceReportStatus.behindPace);
      expect(behind.dailyTarget, 7);

      final early = onTrack(ProjectionStatus.tooEarly);
      expect(early.status, PaceReportStatus.tooEarly);
      expect(early.projectionTooEarly, isTrue);
      expect(early.projectedFinish, isNull);
      expect(early.dailyTarget, 3);
    });

    test('only sub-tracks with a positive shortfall get a message', () {
      final view = onTrack(ProjectionStatus.behindPace);
      expect(view.shortfalls, hasLength(1));
      final line = view.shortfalls.single;
      expect(line.subTrackId, school2026);
      expect(line.name, 'School');
      expect(line.shortfall, 12);
      expect(line.node!.ref, 'Berakhot 3');
      expect(line.windowEnd, '2027-06-30');
    });

    test('no deadline: projected finish only, no status, no target, no '
        'shortfall (AC-7)', () {
      final view = onTrack(ProjectionStatus.noDeadline, dailyTarget: null);
      expect(view.status, isNull);
      expect(view.dailyTarget, isNull);
      expect(view.shortfalls, isEmpty);
      expect(view.projectedFinish, '2029-03-14');
    });

    test('too early with no deadline has no status chip either', () {
      final view = onTrack(ProjectionStatus.tooEarly, dailyTarget: null);
      expect(view.status, isNull);
      expect(view.projectionTooEarly, isTrue);
    });

    test('a calendar program takes its status from the engine calendar '
        'shortfall (AC-8)', () {
      final behind = onTrack(
        ProjectionStatus.noDeadline,
        calendar: true,
        shortfall: 4,
        dailyTarget: 5,
        subTracks: const {},
      );
      expect(behind.calendarProgram, isTrue);
      expect(behind.status, PaceReportStatus.behindPace);
      expect(behind.calendarShortfall, 4);
      expect(behind.dailyTarget, 5);

      final caughtUp = onTrack(
        ProjectionStatus.noDeadline,
        calendar: true,
        shortfall: 0,
        dailyTarget: 1,
        subTracks: const {},
      );
      expect(caughtUp.status, PaceReportStatus.onTrack);
      expect(caughtUp.calendarShortfall, isNull);

      final noStart = onTrack(
        ProjectionStatus.noDeadline,
        calendar: true,
        dailyTarget: null,
        subTracks: const {},
      );
      expect(noStart.status, PaceReportStatus.tooEarly);
    });
  });
}
