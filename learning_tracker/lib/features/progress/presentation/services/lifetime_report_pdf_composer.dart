/// Turns the report screen's views into the printable document (Story
/// 5.4, DNI-519; AD-48, CAP-12).
///
/// [composeLifetimeReportPdf] reads the same [LifetimeReportView] and
/// [PaceReportView] the screen renders (both straight from the engine's
/// `LearnerState` report projection) and writes down what the screen
/// shows, with the screen's strings and number formats: Distinct and
/// Learning events, the On-track block and Per-source pace of an evaluated
/// curriculum, By source, and School years with every group expanded. It
/// counts, adds and derives nothing (AC-2).
///
/// The sections follow the screen exactly: a learner with no counted event
/// gets the zero totals only, and one with no sub-tracks no School years
/// section (AC-6, UX-DR-143); a sub-track named in Hebrew, a renamed one
/// and an ended or deleted one appear under the same group name and with
/// the same "Ended" marker as on screen (AC-5). Units and the curriculum
/// name follow the Hebrew-terms setting (UX-DR-11).
library;

import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/on_track_report_block.dart'
    show reportStatusText;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The report of [view] (and [pace], null when the curriculum is not
/// evaluated) as a printable document for [learnerName], generated on
/// [today] (the learner's civil date in their time zone, AD-41).
///
/// [localeTag] formats numbers and dates as the screen does; [rtl] is the
/// UI's direction. [useHebrewTerms] and [variant] are the Hebrew-terms
/// setting and transliteration the screen's labels follow.
LifetimeReportPdfDocument composeLifetimeReportPdf({
  required LifetimeReportView view,
  required PaceReportView? pace,
  required AppLocalizations l10n,
  required String localeTag,
  required bool rtl,
  required bool useHebrewTerms,
  required TransliterationVariant variant,
  required String learnerName,
  required CivilDate today,
}) {
  final f = _ReportFormat(
    l10n: l10n,
    localeTag: localeTag,
    rtl: rtl,
    useHebrewTerms: useHebrewTerms,
    variant: variant,
    view: view,
  );
  final curriculum = view.curriculum;
  final curriculumName = curriculum == null
      ? view.curriculumId
      : curriculumLabelFor(
          curriculum,
          useHebrewTerms: useHebrewTerms,
          variant: variant,
        );
  // The screen's sections, in its (phone) order.
  final paceView = view.isEmpty ? null : pace;
  final onTrack = paceView?.onTrack;
  return LifetimeReportPdfDocument(
    title: l10n.reportTitle,
    learnerName: learnerName.trim(),
    curriculumName: curriculumName,
    generatedOn: l10n.reportPdfGeneratedOn(f.day(today)),
    pageLabel: l10n.reportPdfPageLabel('{page}', '{total}'),
    rtl: rtl,
    sections: [
      _totals(f),
      if (onTrack != null) _onTrack(f, onTrack),
      if (paceView != null && paceView.rows.isNotEmpty) _pace(f, paceView),
      if (!view.isEmpty) _bySource(f),
      if (!view.isEmpty && view.groups.isNotEmpty) _schoolYears(f),
    ],
  );
}

/// The screen's formatting, without a widget tree.
final class _ReportFormat {
  _ReportFormat({
    required this.l10n,
    required this.localeTag,
    required this.rtl,
    required this.useHebrewTerms,
    required this.variant,
    required this.view,
  });

  final AppLocalizations l10n;
  final String localeTag;
  final bool rtl;
  final bool useHebrewTerms;
  final TransliterationVariant variant;
  final LifetimeReportView view;

  late final NumberFormat _count = NumberFormat.decimalPattern(localeTag);
  late final NumberFormat _rate = NumberFormat.decimalPattern(localeTag)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 1;

  /// "1,204" (`formatReportCount`).
  String count(int value) => _count.format(value);

  /// "9.6" (`formatReportRate`).
  String rate(double value) => _rate.format(value);

  /// "Mar 14, 2029" (`formatReportDay`).
  String day(CivilDate date) =>
      DateFormat.yMMMd(localeTag).format(parseCivilDay(date));

  /// "June 2027" (`formatReportMonth`).
  String month(CivilDate date) =>
      DateFormat.yMMMM(localeTag).format(parseCivilDay(date));

  /// The leaf unit, singular for one (`reportUnit`).
  String unit(int count) {
    final curriculum = view.curriculum;
    if (curriculum == null) return l10n.reportUnitFallback;
    return CurriculumLabels.leaf(curriculum).inLanguage(
      useHebrew: useHebrewTerms,
      plural: count != 1,
      variant: variant,
    );
  }

  /// A name the learner typed, kept in its own direction.
  String name(String value) => closeDirection(value, rtl: rtl);

  /// A year or date range, left to right in either direction.
  String range(String label) => leftToRight(label);

  /// The source chip text of [kind] (`ReportSourceChip` labels).
  String sourceLabel(LifetimeReportSourceKind kind, String? sourceName) =>
      switch (kind) {
        LifetimeReportSourceKind.home => l10n.reportSourceHome,
        LifetimeReportSourceKind.beforeTracking =>
          l10n.reportSourceBeforeTracking,
        LifetimeReportSourceKind.unknown => l10n.reportSourceUnknown,
        _ => sourceName == null ? l10n.reportSourceUnknown : name(sourceName),
      };
}

/// Distinct and Learning events (`LifetimeReportTotals`).
LifetimeReportPdfSection _totals(_ReportFormat f) {
  final report = f.view.report;
  return LifetimeReportPdfSection(
    key: 'totals',
    rows: [
      LifetimeReportPdfRow(
        f.l10n.reportDistinctSemantics(
          f.count(report.distinctLearnt),
          f.unit(report.distinctLearnt),
        ),
        style: LifetimeReportPdfRowStyle.figure,
      ),
      LifetimeReportPdfRow(
        f.l10n.reportLearningEventsSemantics(f.count(report.totalEvents)),
        style: LifetimeReportPdfRowStyle.figure,
      ),
    ],
  );
}

/// The On-track block and its shortfall messages (`OnTrackReportBlock`).
LifetimeReportPdfSection _onTrack(_ReportFormat f, OnTrackView view) {
  final l10n = f.l10n;
  final status = view.status;
  final finish = view.projectedFinish;
  final String? finishText;
  if (finish != null) {
    finishText = l10n.reportOnTrackFinish(f.day(finish));
  } else if (status == PaceReportStatus.tooEarly) {
    finishText = null;
  } else if (view.projectionTooEarly) {
    finishText = l10n.reportOnTrackFinishTooEarly;
  } else {
    finishText = l10n.reportOnTrackFinishUnknown;
  }
  final target = view.dailyTarget;
  final behind = view.calendarShortfall;
  return LifetimeReportPdfSection(
    key: 'onTrack',
    title: l10n.reportOnTrackTitle,
    rows: [
      if (status != null)
        LifetimeReportPdfRow(
          reportStatusText(l10n, status),
          style: LifetimeReportPdfRowStyle.heading,
        ),
      if (finishText != null) LifetimeReportPdfRow(finishText),
      if (target != null)
        LifetimeReportPdfRow(
          l10n.reportOnTrackDailyTarget(f.count(target), f.unit(target)),
        ),
      if (behind != null)
        LifetimeReportPdfRow(
          l10n.reportOnTrackCalendarBehind(f.count(behind), f.unit(behind)),
          style: LifetimeReportPdfRowStyle.warning,
        ),
      for (final line in view.shortfalls)
        LifetimeReportPdfRow(
          _shortfallText(f, line),
          style: LifetimeReportPdfRowStyle.warning,
        ),
    ],
  );
}

String _shortfallText(_ReportFormat f, PaceShortfallLine line) {
  final l10n = f.l10n;
  final name = line.name == null
      ? l10n.reportSourceUnknown
      : f.name(line.name!);
  // As on screen: the ground entry is named by its stored ref.
  final node = line.node?.ref ?? name;
  final count = f.count(line.shortfall);
  final unit = f.unit(line.shortfall);
  final end = line.windowEnd;
  return end == null
      ? l10n.reportOnTrackShortfallNoEnd(name, node, count, unit)
      : l10n.reportOnTrackShortfall(name, node, f.month(end), count, unit);
}

/// Per-source pace (`PerSourcePaceSection`): one block per source, kept
/// together on a page, and the before-tracking footnote.
LifetimeReportPdfSection _pace(_ReportFormat f, PaceReportView view) {
  final l10n = f.l10n;
  final unit = f.unit(2);
  final sinceLabel = l10n.reportPaceSinceStart(unit);
  String rate(ReportVelocityFigure figure) =>
      l10n.reportPaceRate(f.rate(figure.leavesPerWeek));
  final rows = <LifetimeReportPdfRow>[];
  for (final row in view.rows) {
    final since = row.velocity.sinceTracking;
    final trailing = row.velocity.trailing;
    final estimate = row.estimatePerWeek;
    final heading = [
      f.sourceLabel(row.kind, row.name),
      if (row.line case final line?) f.range(line.label),
      if (row.ended) l10n.reportLineEnded,
    ].join(' · ');
    final lines = <(String, LifetimeReportPdfRowStyle)>[
      (heading, LifetimeReportPdfRowStyle.heading),
      (
        '$sinceLabel: ${since == null ? l10n.reportPaceTooEarly : rate(since)}',
        LifetimeReportPdfRowStyle.body,
      ),
      (
        trailing == null
            ? l10n.reportPaceTooEarly
            : l10n.reportPaceTrailing(
                f.count(trailing.days),
                f.rate(trailing.leavesPerWeek),
              ),
        LifetimeReportPdfRowStyle.detail,
      ),
      if (estimate != null)
        (
          l10n.reportPaceEstimate(f.rate(estimate)),
          LifetimeReportPdfRowStyle.detail,
        ),
    ];
    for (final (i, (text, style)) in lines.indexed) {
      rows.add(
        LifetimeReportPdfRow(
          text,
          style: style,
          keepWithNext: i < lines.length - 1,
        ),
      );
    }
  }
  return LifetimeReportPdfSection(
    key: 'pace',
    title: l10n.reportPaceTitle,
    rows: rows,
    footnote: l10n.reportPaceFootnote,
  );
}

/// By source (`LifetimeReportBySource`).
LifetimeReportPdfSection _bySource(_ReportFormat f) {
  final l10n = f.l10n;
  return LifetimeReportPdfSection(
    key: 'bySource',
    title: l10n.reportBySource,
    rows: [
      for (final row in f.view.sourceRows) ...[
        LifetimeReportPdfRow(
          [
            f.sourceLabel(row.kind, row.name),
            if (row.line case final line?) f.range(line.label),
          ].join(' · '),
          style: LifetimeReportPdfRowStyle.heading,
          keepWithNext: true,
        ),
        LifetimeReportPdfRow(
          l10n.reportSourceCounts(
            f.count(row.events),
            f.count(row.distinct),
            f.unit(row.distinct),
          ),
        ),
      ],
    ],
  );
}

/// School years with every group expanded (`LifetimeReportSchoolYears`).
LifetimeReportPdfSection _schoolYears(_ReportFormat f) {
  final l10n = f.l10n;
  final rows = <LifetimeReportPdfRow>[];
  for (final group in f.view.groups) {
    final ongoing = group.members.every((m) => m.type == SubTrackType.ongoing);
    rows.add(
      LifetimeReportPdfRow(
        [
          f.name(group.name),
          if (ongoing) l10n.reportGroupOngoing,
          l10n.reportCountWithUnit(
            f.count(group.distinctLeaves),
            f.unit(group.distinctLeaves),
          ),
        ].join(' · '),
        style: LifetimeReportPdfRowStyle.heading,
        keepWithNext: group.members.isNotEmpty,
      ),
    );
    for (final member in group.members) {
      final distinct = member.totals.distinctLeaves;
      final ended = member.status == ReportLineStatus.ended;
      rows.add(
        LifetimeReportPdfRow(
          [
            f.range(member.label),
            if (ended) l10n.reportLineEnded else l10n.reportLineInProgress,
            l10n.reportCountWithUnit(f.count(distinct), f.unit(distinct)),
          ].join(' · '),
          indent: 1,
        ),
      );
    }
  }
  return LifetimeReportPdfSection(
    key: 'schoolYears',
    title: l10n.reportSchoolYears,
    rows: rows,
  );
}
