/// The lifetime report's sections (Story 5.2, DNI-517; screen #14).
///
/// Every number is a [ReportProjection] value, formatted and nothing more
/// (AD-48): the headline totals, the display-only By-source rows and the
/// School years disclosures. Cards are flat with a 1 px outline
/// (UX-DR-15); totals use `headlineSmall` numerals (UX-DR-12); rows wrap
/// instead of clipping at large text and in Hebrew (UX-DR-156, UX-DR-161).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Formats report numbers for the current locale ("1,204").
String formatReportCount(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

/// The curriculum's leaf unit ("mishnayos", "משניות"), singular for one,
/// following the Hebrew-terms setting and nusach (PRD deviation #12: units
/// are curriculum-specific, never hard-coded).
String reportUnit(
  WidgetRef ref,
  AppLocalizations l10n,
  CurriculumId? curriculum, {
  required int count,
}) {
  if (curriculum == null) return l10n.reportUnitFallback;
  return CurriculumLabels.leaf(curriculum).inLanguage(
    useHebrew: ref.watch(effectiveUseHebrewTermsProvider),
    plural: count != 1,
    variant: ref.watch(currentTransliterationVariantProvider),
  );
}

/// A flat card with a 1 px outline and no shadow (UX-DR-15).
class LifetimeReportCard extends StatelessWidget {
  /// Creates the card.
  const LifetimeReportCard({super.key, required this.child, this.title});

  /// The card's section title, if any.
  final String? title;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.brandInk,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// One headline total: "Distinct · 1,204 mishnayos" or
/// "Learning events · 1,876".
class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticsLabel,
    this.unit,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return LifetimeReportCard(
      key: tileKey,
      child: Semantics(
        label: semanticsLabel,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.brandInk2),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.brandInk2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.brandInk,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.brandInk2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Distinct and Learning events totals (AC-1, AC-8).
class LifetimeReportTotals extends ConsumerWidget {
  /// Creates the totals.
  const LifetimeReportTotals({super.key, required this.view});

  /// The report.
  final LifetimeReportView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final report = view.report;
    final distinct = formatReportCount(context, report.distinctLearnt);
    final events = formatReportCount(context, report.totalEvents);
    final unit = reportUnit(
      ref,
      l10n,
      view.curriculum,
      count: report.distinctLearnt,
    );
    final tiles = [
      _TotalTile(
        tileKey: const ValueKey('lifetimeReportDistinct'),
        icon: Icons.menu_book_outlined,
        label: l10n.reportDistinctLabel,
        value: distinct,
        unit: unit,
        semanticsLabel: l10n.reportDistinctSemantics(distinct, unit),
      ),
      _TotalTile(
        tileKey: const ValueKey('lifetimeReportEvents'),
        icon: Icons.event_note_outlined,
        label: l10n.reportLearningEventsLabel,
        value: events,
        semanticsLabel: l10n.reportLearningEventsSemantics(events),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side when there is room; stacked on narrow screens and
        // at large text so nothing clips (UX-DR-156).
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final sideBySide = constraints.maxWidth >= 420 && scale <= 1.3;
        if (!sideBySide) {
          return Column(
            children: [tiles[0], const SizedBox(height: 12), tiles[1]],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ],
          ),
        );
      },
    );
  }
}

/// A display-only source chip (UX-DR-21): no tap action.
class ReportSourceChip extends StatelessWidget {
  /// Creates the chip.
  const ReportSourceChip({super.key, required this.kind, required this.label});

  /// The source type; picks the icon and, for Before tracking, the
  /// gold-soft badge treatment.
  final LifetimeReportSourceKind kind;

  /// The chip text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final beforeTracking = kind == LifetimeReportSourceKind.beforeTracking;
    final foreground = beforeTracking ? colors.brandGoldDeep : colors.brandInk2;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: beforeTracking ? colors.brandGoldSoft : colors.brandCreamSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: beforeTracking ? colors.brandGold : colors.brandOutline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (kind) {
              LifetimeReportSourceKind.home => Icons.home_outlined,
              LifetimeReportSourceKind.schoolYear => Icons.school_outlined,
              LifetimeReportSourceKind.ongoing => Icons.person_outline,
              LifetimeReportSourceKind.unknown => Icons.alt_route,
              LifetimeReportSourceKind.beforeTracking => Icons.history,
            },
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The By source section: one row per projection source (AC-3).
class LifetimeReportBySource extends ConsumerWidget {
  /// Creates the section.
  const LifetimeReportBySource({super.key, required this.view});

  /// The report.
  final LifetimeReportView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final rows = view.sourceRows;
    return LifetimeReportCard(
      key: const ValueKey('lifetimeReportBySource'),
      title: l10n.reportBySource,
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: colors.brandOutlineMuted),
            Padding(
              key: ValueKey('lifetimeReportSource-${row.totals.source}'),
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ReportSourceChip(
                        kind: row.kind,
                        label: switch (row.kind) {
                          LifetimeReportSourceKind.home =>
                            l10n.reportSourceHome,
                          LifetimeReportSourceKind.beforeTracking =>
                            l10n.reportSourceBeforeTracking,
                          LifetimeReportSourceKind.unknown =>
                            l10n.reportSourceUnknown,
                          _ => row.name ?? l10n.reportSourceUnknown,
                        },
                      ),
                      if (row.line case final line?)
                        Text(
                          line.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.brandInk2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.reportSourceCounts(
                      formatReportCount(context, row.events),
                      formatReportCount(context, row.distinct),
                      reportUnit(
                        ref,
                        l10n,
                        view.curriculum,
                        count: row.distinct,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.brandInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The School years section: one disclosure per roll-up group (AC-4–AC-6).
/// Hidden by the screen when there are no sub-tracks (AC-7).
class LifetimeReportSchoolYears extends StatelessWidget {
  /// Creates the section.
  const LifetimeReportSchoolYears({super.key, required this.view});

  /// The report.
  final LifetimeReportView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return LifetimeReportCard(
      key: const ValueKey('lifetimeReportSchoolYears'),
      title: l10n.reportSchoolYears,
      child: Column(
        children: [
          for (final (i, group) in view.groups.indexed) ...[
            if (i > 0) Divider(height: 1, color: colors.brandOutlineMuted),
            LifetimeReportGroupTile(
              key: ValueKey('lifetimeReportGroup-${group.key}'),
              group: group,
              curriculum: view.curriculum,
            ),
          ],
        ],
      ),
    );
  }
}

/// One roll-up group: collapsed "School · 640 mishnayos", expanding to a
/// line per member (UX-DR-43). The expanded state is local to the tile:
/// toggling it re-reads nothing (AC-13).
class LifetimeReportGroupTile extends ConsumerStatefulWidget {
  /// Creates the tile.
  const LifetimeReportGroupTile({
    super.key,
    required this.group,
    required this.curriculum,
  });

  /// The projection group.
  final ReportGroup group;

  /// The curriculum, for the unit.
  final CurriculumId? curriculum;

  @override
  ConsumerState<LifetimeReportGroupTile> createState() =>
      _LifetimeReportGroupTileState();
}

class _LifetimeReportGroupTileState
    extends ConsumerState<LifetimeReportGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final group = widget.group;
    final count = formatReportCount(context, group.distinctLeaves);
    final unit = reportUnit(
      ref,
      l10n,
      widget.curriculum,
      count: group.distinctLeaves,
    );
    final ongoing = group.members.every((m) => m.type == SubTrackType.ongoing);
    final header = [
      group.name,
      if (ongoing) l10n.reportGroupOngoing,
      l10n.reportCountWithUnit(count, unit),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: header,
          onTapHint: _expanded
              ? l10n.reportGroupCollapseHint
              : l10n.reportGroupExpandHint,
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('lifetimeReportGroupHeader-${group.key}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      ongoing ? Icons.person_outline : Icons.school_outlined,
                      size: 20,
                      color: colors.brandInk2,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        header,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.brandInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: colors.brandInk2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final member in group.members)
            _MemberLine(
              key: ValueKey('lifetimeReportLine-${member.subTrackId}'),
              member: member,
              curriculum: widget.curriculum,
            ),
      ],
    );
  }
}

/// One member line: "2026–27 · In progress · 180 mishnayos", or "Ended"
/// for an ended or deleted member (AC-4, AC-5). Ended is never
/// "completed" (UX-DR-70).
class _MemberLine extends ConsumerWidget {
  const _MemberLine({super.key, required this.member, this.curriculum});

  final ReportMemberLine member;
  final CurriculumId? curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final distinct = member.totals.distinctLeaves;
    final ended = member.status == ReportLineStatus.ended;
    final marker = ended ? l10n.reportLineEnded : l10n.reportLineInProgress;
    final count = l10n.reportCountWithUnit(
      formatReportCount(context, distinct),
      reportUnit(ref, l10n, curriculum, count: distinct),
    );
    return Semantics(
      label: [member.label, marker, count].join(' · '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(28, 6, 4, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              member.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: ended ? colors.surfaceF3 : colors.brandBlueSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                marker,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ended ? colors.brandInk2 : colors.brandBlueDeep,
                ),
              ),
            ),
            Text(
              count,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInk2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
