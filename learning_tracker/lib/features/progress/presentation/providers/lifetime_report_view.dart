/// The presentation view of one curriculum's lifetime report (Story 5.2,
/// DNI-517; AD-48).
///
/// Every number here is read unchanged from the engine's
/// [ReportProjection] (Story 5.1, DNI-516). This file only orders and
/// labels the projection's rows for the screen: it counts, adds, unions
/// and groups nothing. A figure the projection does not carry is not
/// shown.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// What a By-source row stands for; it picks the display-only source chip
/// (UX-DR-21).
enum LifetimeReportSourceKind {
  /// The main track: Home.
  home,

  /// A `school_year` sub-track.
  schoolYear,

  /// An `ongoing` sub-track.
  ongoing,

  /// A sub-track ULID with no `sub_tracks` doc: "Ended sub-track".
  unknown,

  /// The Before-tracking bucket (gold-soft badge).
  beforeTracking,
}

/// One By-source row: a projection source and its own totals.
final class LifetimeReportSourceRow {
  /// Creates the row.
  const LifetimeReportSourceRow({
    required this.kind,
    required this.totals,
    this.name,
    this.line,
  });

  /// The chip type.
  final LifetimeReportSourceKind kind;

  /// The source's projection totals, unchanged.
  final ReportSourceTotals totals;

  /// The sub-track's stored (current or tombstoned) name; null for Home,
  /// Before tracking and an unknown sub-track.
  final String? name;

  /// The sub-track's roll-up line (year or window label, ended state);
  /// null for a row that is not a known sub-track.
  final ReportMemberLine? line;

  /// Counted learning events from the source.
  int get events => totals.events;

  /// Distinct leaves with an event from the source.
  int get distinct => totals.distinctLeaves;
}

/// The lifetime report of one curriculum, ready to render.
final class LifetimeReportView {
  /// Creates the view.
  const LifetimeReportView({
    required this.curriculumId,
    required this.curricula,
    required this.report,
  });

  /// The selected curriculum's storage key.
  final String curriculumId;

  /// Every curriculum the learner has a report for, in the app's canonical
  /// curriculum order (unknown keys last, by key): the switcher options.
  final List<String> curricula;

  /// The selected curriculum's projection, unchanged.
  final ReportProjection report;

  /// The selected curriculum as the app enum (unit and name labels); null
  /// for a key the app does not know.
  CurriculumId? get curriculum => CurriculumId.fromStorageKey(curriculumId);

  /// No counted event in this curriculum: only the zero totals render
  /// (AC-8, UX-DR-143).
  bool get isEmpty => report.totalEvents == 0;

  /// The School years section: the projection's sub-track roll-up, in its
  /// own order. Empty with no sub-tracks (AC-7).
  List<ReportGroup> get groups => report.groups;

  /// The By-source rows: Home, then each known sub-track in roll-up order
  /// (group, then member), then any unknown sub-track source, then the
  /// Before-tracking bucket when there is one (AC-3).
  ///
  /// Each projection source appears exactly once, so the rows' events add
  /// up to [ReportProjection.totalEvents] by the projection's own
  /// invariant; this getter adds nothing up.
  List<LifetimeReportSourceRow> get sourceRows {
    final lines = <String, ReportMemberLine>{
      for (final group in report.groups)
        for (final member in group.members) member.subTrackId: member,
    };
    final rows = <LifetimeReportSourceRow>[
      LifetimeReportSourceRow(
        kind: LifetimeReportSourceKind.home,
        totals: report.home,
      ),
    ];
    final listed = <String>{report.home.source};
    for (final group in report.groups) {
      for (final member in group.members) {
        final totals = report.sources[member.subTrackId];
        if (totals == null || !listed.add(member.subTrackId)) continue;
        rows.add(
          LifetimeReportSourceRow(
            kind: member.type == SubTrackType.schoolYear
                ? LifetimeReportSourceKind.schoolYear
                : LifetimeReportSourceKind.ongoing,
            totals: totals,
            name: member.name.trim(),
            line: member,
          ),
        );
      }
    }
    for (final totals in report.sources.values) {
      if (!listed.add(totals.source)) continue;
      final line = lines[totals.source];
      rows.add(
        LifetimeReportSourceRow(
          kind: line == null
              ? LifetimeReportSourceKind.unknown
              : line.type == SubTrackType.schoolYear
              ? LifetimeReportSourceKind.schoolYear
              : LifetimeReportSourceKind.ongoing,
          totals: totals,
          name: line?.name.trim(),
          line: line,
        ),
      );
    }
    if (report.beforeTracking case final before?) {
      rows.add(
        LifetimeReportSourceRow(
          kind: LifetimeReportSourceKind.beforeTracking,
          totals: before,
        ),
      );
    }
    return rows;
  }

  /// [keys] in the app's canonical curriculum order, unknown keys last.
  static List<String> orderCurricula(Iterable<String> keys) {
    int rank(String key) =>
        CurriculumId.fromStorageKey(key)?.index ?? CurriculumId.values.length;
    return keys.toList()..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  }
}
