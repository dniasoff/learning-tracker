/// The lifetime report's On-track block (Story 5.3, DNI-518; FR-18, FR-21;
/// screen #14; UX-DR-23, UX-DR-24, UX-DR-94, UX-DR-95, UX-DR-157).
///
/// It renders only engine-produced values ([OnTrackView]): the status,
/// projected finish and daily target of the shared learner state (the
/// same the Dashboard reads, AC-11), the calendar shortfall of a
/// calendar-program curriculum, and the FR-21 message of every sub-track
/// with a positive shortfall. It invokes no pace calculator.
///
/// Status is text with an icon, never colour alone (UX-DR-157): "On
/// track" in success green and "Behind pace" in amber are parent-only
/// treatments (UX-DR-6, UX-DR-7); "Too early to tell" is neutral. With no
/// deadline there is no status chip and no daily target (UX-DR-95).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// [date] as a localized day ("Mar 14, 2029").
String formatReportDay(BuildContext context, CivilDate date) =>
    DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(parseCivilDay(date));

/// [date]'s month ("June 2027").
String formatReportMonth(BuildContext context, CivilDate date) =>
    DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(parseCivilDay(date));

/// The status text of [status].
String reportStatusText(AppLocalizations l10n, PaceReportStatus status) =>
    switch (status) {
      PaceReportStatus.onTrack => l10n.reportOnTrackStatusOnTrack,
      PaceReportStatus.behindPace => l10n.reportOnTrackStatusBehind,
      PaceReportStatus.tooEarly => l10n.reportPaceTooEarly,
    };

/// The On-track block and the shortfall messages under it (AC-6–AC-8).
class OnTrackReportBlock extends ConsumerWidget {
  /// Creates the block.
  const OnTrackReportBlock({super.key, required this.view, this.curriculum});

  /// The engine's on-track values.
  final OnTrackView view;

  /// The curriculum, for the leaf unit (PRD deviation #12).
  final CurriculumId? curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    String unit(int count) => reportUnit(ref, l10n, curriculum, count: count);

    final status = view.status;
    final finish = view.projectedFinish;
    final String? finishText;
    if (finish != null) {
      finishText = l10n.reportOnTrackFinish(formatReportDay(context, finish));
    } else if (status == PaceReportStatus.tooEarly) {
      // The status line already says it.
      finishText = null;
    } else if (view.projectionTooEarly) {
      finishText = l10n.reportOnTrackFinishTooEarly;
    } else {
      finishText = l10n.reportOnTrackFinishUnknown;
    }
    final target = view.dailyTarget;
    final behind = view.calendarShortfall;
    final body = theme.textTheme.bodyMedium?.copyWith(color: colors.brandInk);

    final block = LifetimeReportCard(
      key: const ValueKey('reportOnTrackBlock'),
      title: l10n.reportOnTrackTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null) ...[
            ReportStatusChip(status: status),
            const SizedBox(height: 8),
          ],
          if (finishText != null)
            Text(
              finishText,
              key: const ValueKey('reportOnTrackFinish'),
              style: body,
            ),
          if (target != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.reportOnTrackDailyTarget(
                formatReportCount(context, target),
                unit(target),
              ),
              key: const ValueKey('reportOnTrackDailyTarget'),
              style: body,
            ),
          ],
          if (behind != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.reportOnTrackCalendarBehind(
                formatReportCount(context, behind),
                unit(behind),
              ),
              key: const ValueKey('reportOnTrackCalendarBehind'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandWarningDeep,
              ),
            ),
          ],
        ],
      ),
    );
    if (view.shortfalls.isEmpty) return block;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        block,
        for (final line in view.shortfalls) ...[
          const SizedBox(height: 8),
          _ShortfallCard(
            key: ValueKey('reportShortfall-${line.subTrackId}'),
            message: _shortfallText(context, l10n, line, unit(line.shortfall)),
          ),
        ],
      ],
    );
  }

  String _shortfallText(
    BuildContext context,
    AppLocalizations l10n,
    PaceShortfallLine line,
    String unit,
  ) {
    final name = line.name ?? l10n.reportSourceUnknown;
    // [ASSUMPTION] The ground entry is named by its stored ref until a
    // shared ContentIndex label formatter exists (follow-up bead).
    final node = line.node?.ref ?? name;
    final count = formatReportCount(context, line.shortfall);
    final end = line.windowEnd;
    return end == null
        ? l10n.reportOnTrackShortfallNoEnd(name, node, count, unit)
        : l10n.reportOnTrackShortfall(
            name,
            node,
            formatReportMonth(context, end),
            count,
            unit,
          );
  }
}

/// The status as icon and text in its parent-only tone (UX-DR-157).
class ReportStatusChip extends StatelessWidget {
  /// Creates the chip.
  const ReportStatusChip({super.key, required this.status});

  /// The engine's status.
  final PaceReportStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = reportStatusText(l10n, status);
    final (background, foreground, icon) = switch (status) {
      PaceReportStatus.onTrack => (
        colors.statusSuccessSoftBg,
        colors.statusSuccessSoftText,
        Icons.check_circle_outline,
      ),
      PaceReportStatus.behindPace => (
        colors.brandWarningSoft,
        colors.brandWarningDeep,
        Icons.trending_down,
      ),
      PaceReportStatus.tooEarly => (
        colors.brandCreamSoft,
        colors.brandInkMuted,
        Icons.hourglass_empty,
      ),
    };
    return Semantics(
      label: l10n.reportOnTrackStatusSemantics(text),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('reportOnTrackStatus'),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 12, 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One FR-21 shortfall message, full width under the block (parent only).
class _ShortfallCard extends StatelessWidget {
  const _ShortfallCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.brandWarningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: colors.brandWarningDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.brandWarningDeep),
            ),
          ),
        ],
      ),
    );
  }
}
