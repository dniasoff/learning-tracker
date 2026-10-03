/// Report projections for the Story 5.2 (DNI-517) lifetime report tests.
///
/// The projection is the engine's (Story 5.1, DNI-516) output type; these
/// builders only stand one up with chosen numbers, so a test can check
/// the screen shows them unchanged.
library;

import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../learner_state/fake_learner_state.dart';

/// The fixtures' curriculum.
const reportCurriculum = 'mishnayos';

/// A second, retired curriculum (AC-9).
const reportRetiredCurriculum = 'chumash';

/// Sub-track ULIDs (sorted as the engine would list them).
const school2024 = '01J0000000000000000000S024';
const school2025 = '01J0000000000000000000S025';
const school2026 = '01J0000000000000000000S026';
const rebbeId = '01J0000000000000000000RBBE';

/// [distinct] leaves unique to [source], so a union never overlaps.
Set<String> _leaves(String source, int distinct) => {
  for (var i = 0; i < distinct; i++) 'Mishnah $source $i',
};

/// One source's totals.
ReportSourceTotals reportTotals(
  String source, {
  required int events,
  required int distinct,
  ReportSourceKind? kind,
}) => ReportSourceTotals(
  source: source,
  kind:
      kind ??
      (source == LearningEvent.sourceMain
          ? ReportSourceKind.main
          : source == reportBeforeTrackingKey
          ? ReportSourceKind.beforeTracking
          : ReportSourceKind.subTrack),
  events: events,
  leaves: _leaves(source, distinct),
);

/// A `school_year` member line for [academicYear].
ReportMemberLine schoolYearLine(
  String id,
  int academicYear,
  ReportSourceTotals totals, {
  String name = 'School',
  bool ended = false,
  SubTrackEndReason? endReason,
}) => ReportMemberLine(
  subTrackId: id,
  name: name,
  type: SubTrackType.schoolYear,
  academicYear: academicYear,
  windowStart: '$academicYear-09-01',
  windowEnd: '${academicYear + 1}-06-30',
  label: reportSchoolYearLabel(academicYear),
  endedAt: ended ? DateTime.utc(academicYear + 1, 7) : null,
  endedOn: ended ? '${academicYear + 1}-07-01' : null,
  endReason: ended ? (endReason ?? SubTrackEndReason.ended) : null,
  totals: totals,
);

/// An `ongoing` member line.
ReportMemberLine ongoingLine(
  String id,
  ReportSourceTotals totals, {
  String name = 'Rebbe',
}) => ReportMemberLine(
  subTrackId: id,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2025-01-05',
  label: reportWindowLabel('2025-01-05', null),
  totals: totals,
);

/// The AC-3/AC-4 learner: Home, three "School" years (2024 and 2025
/// ended, 2026 active), an ongoing "Rebbe" and Before-tracking backfill.
///
/// [deleted2025] tombstones the 2025 year instead of ending it (AC-5).
ReportProjection fullReport({
  bool deleted2025 = false,
  String curriculumId = reportCurriculum,
}) {
  final home = reportTotals(
    LearningEvent.sourceMain,
    events: 1020,
    distinct: 700,
  );
  final s24 = reportTotals(school2024, events: 260, distinct: 210);
  final s25 = reportTotals(school2025, events: 300, distinct: 250);
  final s26 = reportTotals(school2026, events: 190, distinct: 180);
  final rebbe = reportTotals(rebbeId, events: 230, distinct: 216);
  final before = reportTotals(
    reportBeforeTrackingKey,
    events: 40,
    distinct: 40,
  );
  return ReportProjection(
    curriculumId: curriculumId,
    distinctLearnt: 1204,
    totalEvents: 1020 + 260 + 300 + 190 + 230 + 40,
    sources: {
      LearningEvent.sourceMain: home,
      rebbeId: rebbe,
      school2024: s24,
      school2025: s25,
      school2026: s26,
    },
    beforeTracking: before,
    groups: [
      ReportGroup(
        key: 'rebbe',
        name: 'Rebbe',
        members: [ongoingLine(rebbeId, rebbe)],
      ),
      ReportGroup(
        key: 'school',
        name: 'School',
        members: [
          schoolYearLine(school2024, 2024, s24, ended: true),
          schoolYearLine(
            school2025,
            2025,
            s25,
            ended: true,
            endReason: deleted2025
                ? SubTrackEndReason.deleted
                : SubTrackEndReason.ended,
          ),
          schoolYearLine(school2026, 2026, s26),
        ],
      ),
    ],
  );
}

/// A learner with Home learning only, plus optional Before tracking
/// (AC-7).
ReportProjection homeOnlyReport({
  int events = 12,
  int distinct = 10,
  bool withBeforeTracking = true,
  String curriculumId = reportCurriculum,
}) {
  final home = reportTotals(
    LearningEvent.sourceMain,
    events: events,
    distinct: distinct,
  );
  final before = withBeforeTracking
      ? reportTotals(reportBeforeTrackingKey, events: 5, distinct: 5)
      : null;
  return ReportProjection(
    curriculumId: curriculumId,
    distinctLearnt: distinct + (before?.distinctLeaves ?? 0),
    totalEvents: events + (before?.events ?? 0),
    sources: {LearningEvent.sourceMain: home},
    beforeTracking: before,
  );
}

/// A [LearnerState] holding [reports] by curriculum.
LearnerState reportState(List<ReportProjection> reports) => LearnerState(
  nowUtc: fakeLearnerStateNow,
  curricula: {
    for (final r in reports)
      r.curriculumId: FakeCurriculumState(
        curriculumId: r.curriculumId,
        report: r,
      ),
  },
);
