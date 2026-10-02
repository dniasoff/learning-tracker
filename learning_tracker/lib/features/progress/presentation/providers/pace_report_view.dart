/// The per-source pace and on-track presentation view of the lifetime
/// report (Story 5.3, DNI-518; FR-18, FR-21, FR-32; AD-35, AD-48).
///
/// Every figure here is read unchanged from the engine: per-source and
/// trailing velocity from [ReportProjection] (Story 5.1, DNI-516), status,
/// projected finish, daily target and shortfalls from the curriculum's
/// [CurriculumState]. This file selects and orders those values for the
/// screen; it computes no total, velocity, status or shortfall, and never
/// calls the legacy pace calculators.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';

/// The on-track status a parent sees (UX-DR-23, UX-DR-94).
enum PaceReportStatus {
  /// "On track" (success green, parent only).
  onTrack,

  /// "Behind pace" (amber, parent only).
  behindPace,

  /// "Too early to tell" (neutral).
  tooEarly,
}

/// One Per-source pace row: a projection source and its own velocity.
final class PaceSourceRow {
  /// Creates the row.
  const PaceSourceRow({
    required this.source,
    required this.kind,
    required this.velocity,
    this.name,
    this.line,
    this.estimatePerWeek,
    this.ended = false,
  });

  /// `main` or the sub-track ULID.
  final String source;

  /// The chip type (UX-DR-21).
  final LifetimeReportSourceKind kind;

  /// The engine's velocity of this source over its own window, unchanged.
  final ReportVelocity velocity;

  /// The sub-track's stored name; null for Home and an unknown sub-track.
  final String? name;

  /// The sub-track's roll-up line; null for Home and an unknown sub-track.
  final ReportMemberLine? line;

  /// The stored `rate_per_week` of an active sub-track; null for Home, an
  /// unknown sub-track and an ended or deleted one (no estimate
  /// comparison, AC-5).
  final double? estimatePerWeek;

  /// An ended or deleted sub-track (or a ULID with no doc): labelled
  /// "Ended", measured over its own window, no estimate and no status.
  final bool ended;
}

/// One sub-track that will not finish its ground by the deadline (FR-21).
final class PaceShortfallLine {
  /// Creates the line.
  const PaceShortfallLine({
    required this.subTrackId,
    required this.shortfall,
    this.name,
    this.node,
    this.windowEnd,
  });

  /// The sub-track ULID.
  final String subTrackId;

  /// The stored sub-track name; null when the report does not list it.
  final String? name;

  /// The engine's FR-19 shortfall of this sub-track, in leaves (> 0).
  final int shortfall;

  /// The last ground entry with a shortfall leaf.
  final NodeEntry? node;

  /// The sub-track's `window_end`; null for an open window.
  final CivilDate? windowEnd;
}

/// The On-track block: the engine's status, projection and daily target.
final class OnTrackView {
  /// Creates the view.
  const OnTrackView({
    required this.calendarProgram,
    this.status,
    this.projectionTooEarly = false,
    this.projectedFinish,
    this.dailyTarget,
    this.calendarShortfall,
    this.shortfalls = const [],
  });

  /// A calendar-program curriculum: status is the engine's calendar
  /// shortfall (AC-8).
  final bool calendarProgram;

  /// The status chip; null with no deadline goal (UX-DR-95, AC-7).
  final PaceReportStatus? status;

  /// The engine made no finish projection yet: under 14 days of tracked
  /// history (AD-35, UX-DR-94).
  final bool projectionTooEarly;

  /// The engine's projected finish; null when there is none.
  final CivilDate? projectedFinish;

  /// The engine's daily target; null with no deadline (AC-7).
  final int? dailyTarget;

  /// Calendar programs: leaves assigned before today and not learnt,
  /// when positive.
  final int? calendarShortfall;

  /// Sub-tracks with a positive shortfall, in report order (AC-6).
  final List<PaceShortfallLine> shortfalls;

  /// The block for [state], whose report is [report]; null when the
  /// engine made no projection (a curriculum that is not evaluated).
  static OnTrackView? of(CurriculumState state, ReportProjection report) {
    final projection = state.projection;
    if (projection == null) return null;
    if (report.calendarProgram) {
      // AC-8: the engine's calendar shortfall (assigned through today
      // minus learnt, before today) is the status; null when the program
      // has no tracking start yet.
      final shortfall = state.shortfall;
      return OnTrackView(
        calendarProgram: true,
        status: switch (shortfall) {
          null => PaceReportStatus.tooEarly,
          0 => PaceReportStatus.onTrack,
          _ => PaceReportStatus.behindPace,
        },
        projectionTooEarly: projection.status == ProjectionStatus.tooEarly,
        projectedFinish: projection.projectedFinish,
        dailyTarget: state.dailyTarget,
        calendarShortfall: shortfall != null && shortfall > 0
            ? shortfall
            : null,
      );
    }
    // The engine's status is "too early" under 14 days with or without a
    // deadline; without one (no daily target: the engine derives it only
    // from a live deadline) there is no status chip (UX-DR-95).
    final tooEarly = projection.status == ProjectionStatus.tooEarly;
    final deadline = switch (projection.status) {
      ProjectionStatus.onTrack || ProjectionStatus.behindPace => true,
      ProjectionStatus.tooEarly => state.dailyTarget != null,
      ProjectionStatus.noDeadline => false,
    };
    final status = !deadline
        ? null
        : switch (projection.status) {
            ProjectionStatus.onTrack => PaceReportStatus.onTrack,
            ProjectionStatus.behindPace => PaceReportStatus.behindPace,
            _ => PaceReportStatus.tooEarly,
          };
    final members = <String, ReportMemberLine>{
      for (final group in report.groups)
        for (final member in group.members) member.subTrackId: member,
    };
    final order = [...members.keys];
    final shortfalls = [
      for (final MapEntry(:key, :value) in state.subTracks.entries)
        if (value.shortfall > 0 &&
            members[key]?.status != ReportLineStatus.ended)
          PaceShortfallLine(
            subTrackId: key,
            name: members[key]?.name.trim(),
            shortfall: value.shortfall,
            node: value.lastShortfallNode,
            windowEnd: value.windowEnd,
          ),
    ];
    int rank(String id) {
      final i = order.indexOf(id);
      return i < 0 ? order.length : i;
    }

    shortfalls.sort((a, b) {
      final byRank = rank(a.subTrackId).compareTo(rank(b.subTrackId));
      return byRank != 0 ? byRank : a.subTrackId.compareTo(b.subTrackId);
    });
    return OnTrackView(
      calendarProgram: false,
      status: status,
      projectionTooEarly: tooEarly,
      projectedFinish: projection.projectedFinish,
      dailyTarget: deadline ? state.dailyTarget : null,
      shortfalls: deadline ? shortfalls : const [],
    );
  }
}

/// The Per-source pace and On-track sections of one curriculum's report.
final class PaceReportView {
  /// Creates the view.
  const PaceReportView({
    required this.curriculumId,
    required this.rows,
    required this.calendarProgram,
    this.onTrack,
  });

  /// The curriculum's storage key.
  final String curriculumId;

  /// One row per source: Home, then each sub-track source in the report's
  /// By-source order. Home only on a calendar program (AC-8). The
  /// Before-tracking bucket never has a row (UX-DR-69).
  final List<PaceSourceRow> rows;

  /// A calendar-program curriculum.
  final bool calendarProgram;

  /// The On-track block; null when the engine made no projection.
  final OnTrackView? onTrack;

  /// The curriculum as the app enum (unit labels); null when unknown.
  CurriculumId? get curriculum => CurriculumId.fromStorageKey(curriculumId);

  /// The pace view of [report] over [state], the same curriculum's engine
  /// state; null when the curriculum is not evaluated (a retired or
  /// archived curriculum, or one whose corpus is not ready): its report
  /// keeps only the lifetime totals (AC-9).
  static PaceReportView? of(LifetimeReportView report, CurriculumState? state) {
    final projection = report.report;
    if (state == null || !state.evaluated) return null;
    if (state.curriculumId != report.curriculumId) return null;
    // The engine measures velocity for evaluated curricula only.
    if (projection.allSources == null) return null;
    final calendar = projection.calendarProgram;
    final rows = <PaceSourceRow>[
      for (final row in report.sourceRows)
        if (row.kind != LifetimeReportSourceKind.beforeTracking &&
            (!calendar || row.kind == LifetimeReportSourceKind.home))
          _row(row),
    ];
    return PaceReportView(
      curriculumId: report.curriculumId,
      rows: rows,
      calendarProgram: calendar,
      onTrack: OnTrackView.of(state, projection),
    );
  }

  static PaceSourceRow _row(LifetimeReportSourceRow row) {
    final line = row.line;
    final ended =
        row.kind == LifetimeReportSourceKind.unknown ||
        line?.status == ReportLineStatus.ended;
    return PaceSourceRow(
      source: row.totals.source,
      kind: row.kind,
      velocity: row.totals.velocity ?? const ReportVelocity(),
      name: row.name,
      line: line,
      estimatePerWeek: ended ? null : line?.ratePerWeek,
      ended: ended,
    );
  }
}
