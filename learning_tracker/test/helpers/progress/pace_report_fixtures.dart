/// Report projections and curriculum states for the Story 5.3 (DNI-518)
/// Per-source pace and On-track tests.
///
/// The projection and state are the engine's (Story 5.1, DNI-516; Story
/// 2.3) output types; these builders stand them up with chosen numbers so
/// a test can check the report shows them unchanged.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../learner_state/fake_learner_state.dart';
import 'lifetime_report_fixtures.dart';

/// The fixtures' "today".
const paceToday = '2026-10-08';

/// A velocity figure of [leaves] over the [days] days ending [paceToday].
ReportVelocityFigure paceFigure(int leaves, int days) => ReportVelocityFigure(
  from: shiftCivilDate(paceToday, 1 - days),
  through: paceToday,
  days: days,
  leaves: leaves,
);

/// A source velocity: [since] over [sinceDays] days, and a trailing figure
/// of [trailing] over `min(sinceDays, 28)` days, or none under 14 days
/// (as the engine's AD-35 window does).
ReportVelocity paceVelocity(int since, int sinceDays, {int? trailing}) =>
    ReportVelocity(
      sinceTracking: paceFigure(since, sinceDays),
      trailing: sinceDays < 14
          ? null
          : paceFigure(trailing ?? since, sinceDays >= 28 ? 28 : sinceDays),
    );

/// Totals of [source] with [velocity].
ReportSourceTotals paceTotals(
  String source,
  ReportVelocity? velocity, {
  int events = 20,
  int distinct = 15,
  ReportSourceKind? kind,
}) => ReportSourceTotals(
  source: source,
  kind:
      kind ??
      (source == LearningEvent.sourceMain
          ? ReportSourceKind.main
          : ReportSourceKind.subTrack),
  events: events,
  leaves: {for (var i = 0; i < distinct; i++) 'Mishnah $source $i'},
  velocity: velocity,
);

/// A member line with an estimate of [ratePerWeek].
ReportMemberLine paceLine(
  String id,
  ReportSourceTotals totals, {
  required String name,
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  double ratePerWeek = 10,
  bool ended = false,
  SubTrackEndReason endReason = SubTrackEndReason.ended,
  CivilDate windowStart = '2026-09-01',
  CivilDate? windowEnd,
}) => ReportMemberLine(
  subTrackId: id,
  name: name,
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  label: academicYear != null
      ? reportSchoolYearLabel(academicYear)
      : reportWindowLabel(windowStart, windowEnd),
  endedAt: ended ? DateTime.utc(2026, 9, 20) : null,
  endedOn: ended ? '2026-09-20' : null,
  endReason: ended ? endReason : null,
  ratePerWeek: ratePerWeek,
  totals: totals,
);

/// Home at 9.6 / week (since tracking: 48 leaves over 35 days), School
/// 2026 (active, estimate 10 / week) and Rebbe (active, estimate 5 /
/// week), plus a Before-tracking bucket (no pace row).
///
/// [homeDays] shortens the tracked history ([paceVelocity]); [ended2025]
/// adds the ended School 2025 year (its own window, AC-5);
/// [deleted2025] makes it deleted instead.
ReportProjection paceReport({
  int homeDays = 35,
  bool ended2025 = false,
  bool deleted2025 = false,
  bool unknownSource = false,
  bool calendarProgram = false,
  ProjectionStatus status = ProjectionStatus.onTrack,
  String curriculumId = reportCurriculum,
}) {
  final home = paceTotals(
    LearningEvent.sourceMain,
    paceVelocity(48, homeDays, trailing: 32),
  );
  final school = paceTotals(school2026, paceVelocity(30, 35, trailing: 26));
  final rebbe = paceTotals(rebbeId, paceVelocity(10, 20));
  final s25 = paceTotals(
    school2025,
    ReportVelocity(
      sinceTracking: ReportVelocityFigure(
        from: '2026-09-01',
        through: '2026-09-20',
        days: 20,
        leaves: 12,
      ),
      trailing: ReportVelocityFigure(
        from: '2026-09-01',
        through: '2026-09-20',
        days: 20,
        leaves: 12,
      ),
    ),
  );
  const unknownId = '01J0000000000000000000UNKN';
  final unknown = paceTotals(
    unknownId,
    paceVelocity(3, 30),
    kind: ReportSourceKind.unknownSubTrack,
  );
  final withEnded = ended2025 || deleted2025;
  return ReportProjection(
    curriculumId: curriculumId,
    distinctLearnt: 200,
    totalEvents: 260,
    sources: {
      LearningEvent.sourceMain: home,
      rebbeId: rebbe,
      if (withEnded) school2025: s25,
      school2026: school,
      if (unknownSource) unknownId: unknown,
    },
    beforeTracking: paceTotals(
      reportBeforeTrackingKey,
      null,
      events: 500,
      distinct: 40,
      kind: ReportSourceKind.beforeTracking,
    ),
    groups: [
      ReportGroup(
        key: 'rebbe',
        name: 'Rebbe',
        members: [paceLine(rebbeId, rebbe, name: 'Rebbe', ratePerWeek: 5)],
      ),
      ReportGroup(
        key: 'school',
        name: 'School',
        members: [
          if (withEnded)
            paceLine(
              school2025,
              s25,
              name: 'School',
              type: SubTrackType.schoolYear,
              academicYear: 2025,
              ratePerWeek: 8,
              ended: true,
              endReason: deleted2025
                  ? SubTrackEndReason.deleted
                  : SubTrackEndReason.ended,
            ),
          paceLine(
            school2026,
            school,
            name: 'School',
            type: SubTrackType.schoolYear,
            academicYear: 2026,
            windowStart: '2026-09-01',
            windowEnd: '2027-06-30',
          ),
        ],
      ),
    ],
    allSources: paceVelocity(70, homeDays, trailing: 50),
    projectionStatus: status,
    calendarProgram: calendarProgram,
  );
}

/// The engine's projection with [status] and a [finish] day.
Projection paceProjection(
  ProjectionStatus status, {
  CivilDate? finish = '2029-03-14',
}) => Projection(
  status: status,
  velocityPerDay: status == ProjectionStatus.tooEarly ? null : 50 / 28,
  projectedFinish: status == ProjectionStatus.tooEarly ? null : finish,
);

/// School will not reach Berakhot 3 by its window end (FR-21).
const paceSchoolShortfall = SubTrackState(
  subTrackId: school2026,
  holdsGround: true,
  inForecast: true,
  onHome: true,
  capacity: 90,
  shortfall: 12,
  windowEnd: '2027-06-30',
  lastShortfallNode: NodeEntry(level: 'chapter', ref: 'Berakhot 3'),
);

/// Rebbe reaches all its ground (no shortfall).
const paceRebbeNoShortfall = SubTrackState(
  subTrackId: rebbeId,
  holdsGround: true,
  inForecast: true,
  onHome: true,
  capacity: 40,
);

/// The curriculum state of [report] with the engine's plan values.
FakeCurriculumState paceCurriculumState(
  ReportProjection report, {
  Projection? projection,
  int? dailyTarget = 3,
  int? shortfall,
  Map<String, SubTrackState> subTracks = const {
    school2026: paceSchoolShortfall,
    rebbeId: paceRebbeNoShortfall,
  },
  bool evaluated = true,
}) => FakeCurriculumState(
  curriculumId: report.curriculumId,
  evaluated: evaluated,
  report: report,
  projection:
      projection ??
      paceProjection(report.projectionStatus ?? ProjectionStatus.onTrack),
  dailyTarget: dailyTarget,
  shortfall: shortfall,
  subTracks: subTracks,
);

/// A [LearnerState] holding [states].
LearnerState paceState(List<CurriculumState> states) => LearnerState(
  nowUtc: fakeLearnerStateNow,
  curricula: {for (final s in states) s.curriculumId: s},
);
