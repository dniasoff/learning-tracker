/// The lifetime report's Per-source pace section (Story 5.3, DNI-518;
/// FR-32; screen #14; UX-DR-42, UX-DR-69, UX-DR-94).
///
/// One row per source: its chip, the engine's measured velocity since
/// tracking started in `headlineSmall` ("9.6 / week"), the AD-35 trailing
/// figure (or a neutral "Too early to tell" under 14 days), and, for an
/// active sub-track, its stored estimate ("10 / week estimate"). An ended
/// or deleted source is labelled "Ended" and measured over its own window,
/// with no estimate. No row carries a judgment ("On pace", "Steady"):
/// the rates are measured values only (UX-DR-42). Every figure is the
/// engine projection's, formatted and nothing more (AD-48).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Formats a rate to at most one decimal place for the current locale
/// ("9.6", "10").
String formatReportRate(BuildContext context, double value) =>
    (NumberFormat.decimalPattern(
            Localizations.localeOf(context).toLanguageTag(),
          )
          ..minimumFractionDigits = 0
          ..maximumFractionDigits = 1)
        .format(value);

/// The Per-source pace section of one evaluated curriculum (AC-1).
class PerSourcePaceSection extends StatelessWidget {
  /// Creates the section.
  const PerSourcePaceSection({super.key, required this.view});

  /// The pace view.
  final PaceReportView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    return LifetimeReportCard(
      key: const ValueKey('reportPaceSection'),
      title: l10n.reportPaceTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in view.rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: colors.brandOutlineMuted),
            PerSourcePaceRow(
              key: ValueKey('reportPaceRow-${row.source}'),
              row: row,
              curriculum: view.curriculum,
            ),
          ],
          Divider(height: 1, color: colors.brandOutlineMuted),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: colors.brandInk2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.reportPaceFootnote,
                    key: const ValueKey('reportPaceFootnote'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.brandInk2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One source's pace row.
class PerSourcePaceRow extends ConsumerWidget {
  /// Creates the row.
  const PerSourcePaceRow({super.key, required this.row, this.curriculum});

  /// The row.
  final PaceSourceRow row;

  /// The curriculum, for the leaf unit (PRD deviation #12).
  final CurriculumId? curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final unit = reportUnit(ref, l10n, curriculum, count: 2);
    String rate(ReportVelocityFigure figure) =>
        l10n.reportPaceRate(formatReportRate(context, figure.leavesPerWeek));

    final since = row.velocity.sinceTracking;
    final trailing = row.velocity.trailing;
    final sinceText = since == null ? l10n.reportPaceTooEarly : rate(since);
    final trailingText = trailing == null
        ? l10n.reportPaceTooEarly
        : l10n.reportPaceTrailing(
            formatReportCount(context, trailing.days),
            formatReportRate(context, trailing.leavesPerWeek),
          );
    final estimate = row.estimatePerWeek;
    final estimateText = estimate == null
        ? null
        : l10n.reportPaceEstimate(formatReportRate(context, estimate));
    final chipLabel = switch (row.kind) {
      LifetimeReportSourceKind.home => l10n.reportSourceHome,
      LifetimeReportSourceKind.unknown => l10n.reportSourceUnknown,
      _ => row.name ?? l10n.reportSourceUnknown,
    };
    final sinceLabel = l10n.reportPaceSinceStart(unit);
    final semantics = [
      chipLabel,
      if (row.line case final line?) line.label,
      if (row.ended) l10n.reportLineEnded,
      '$sinceLabel: $sinceText',
      trailingText,
      ?estimateText,
    ].join(' · ');

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReportSourceChip(kind: row.kind, label: chipLabel),
                if (row.line case final line?)
                  Text(
                    line.label,
                    // A year or date range reads left to right in Hebrew
                    // too.
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.brandInk2,
                    ),
                  ),
                if (row.ended)
                  Container(
                    key: ValueKey('reportPaceEnded-${row.source}'),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceF3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.reportLineEnded,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.brandInk2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sinceLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.brandInk2,
              ),
            ),
            Text(
              sinceText,
              key: ValueKey('reportPaceSince-${row.source}'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: since == null ? colors.brandInkMuted : colors.brandInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              trailingText,
              key: ValueKey('reportPaceTrailing-${row.source}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                // UX-DR-94: "Too early to tell" is neutral, never amber.
                color: trailing == null
                    ? colors.brandInkMuted
                    : colors.brandInk,
              ),
            ),
            if (estimateText != null) ...[
              const SizedBox(height: 2),
              Text(
                estimateText,
                key: ValueKey('reportPaceEstimate-${row.source}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.brandInkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
