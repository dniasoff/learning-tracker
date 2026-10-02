/// The parent on-track card and its Dashboard section (Story 2.11,
/// DNI-502; screen #03, UX-DR-23, UX-DR-24, UX-DR-75).
///
/// The card formats one [CurriculumForecast] and nothing more: status,
/// projected finish, deadline and daily target are the engine's values
/// (AD-35, AD-44). It holds no state, so a recompute (a new event, a
/// catch-up after a lock, FR-23) is what it shows next frame.
///
/// * On track / Behind pace: status, "Projected finish: … · deadline …",
///   "Daily target: n {unit}/day" (UX-DR-23, UX-DR-24).
/// * Too early to tell (under 14 days of history): neutral status, no
///   projection (UX-DR-94, UX-DR-111).
/// * No deadline: "Projected finish: …" only (FR-20, UX-DR-95).
/// * A zero target with a deadline: the bonus copy (UX-DR-96).
/// * A calendar program: the status is the engine's calendar shortfall,
///   with "n {unit} behind the calendar" when positive.
///
/// The status, daily target and calendar shortfall are the lifetime
/// report's [OnTrackView] of the same state (DNI-518 AC-11), so the two
/// surfaces never disagree. Status is a text label with an icon, never
/// colour alone (UX-DR-157).
/// Parent-only: [ParentForecastSection] reads [parentForecastProvider],
/// which builds nothing outside a parent session (NFR-9, UX-DR-48).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/progress/progress.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The width from which the card lays its lines out as one status row
/// (tablet, DESIGN.md #03).
const double kForecastStatusRowMinWidth = 600;

/// Formats an AD-41 civil date for the current locale ("Mar 14, 2029").
String formatForecastDate(BuildContext context, CivilDate date) =>
    DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.parse(date));

/// Formats a count for the current locale ("1,204").
String formatForecastCount(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

/// The curriculum's leaf unit, plural unless [count] is one ("mishnayos",
/// "משניות"), following the Hebrew-terms setting and nusach (PRD
/// deviation #12: units are curriculum-specific, never hard-coded).
String forecastLeafUnit(
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
class ForecastCardFrame extends StatelessWidget {
  /// Creates the frame.
  const ForecastCardFrame({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
  });

  /// The content.
  final Widget child;

  /// The fill; the theme surface by default.
  final Color? color;

  /// The outline; `brandOutline` by default.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? context.colors.brandOutline),
    ),
    child: child,
  );
}

/// The parent forecast on the Dashboard: one [OnTrackCard] per evaluated
/// curriculum, each followed by its shortfall warnings ([belowCard]).
///
/// Loading is a static placeholder (no spinner after a tick: a refresh
/// keeps the shown state, UX-DR-102); a load error is an
/// [InlineAsyncError] with retry (UX-DR-112). The surface is read-only, so
/// there is no rejected-sync state (UX-DR-113). Outside a parent session,
/// and while the session role is still resolving, it takes no space: the
/// placeholder and error appear only once the parent is confirmed.
class ParentForecastSection extends ConsumerWidget {
  /// Creates the section.
  const ParentForecastSection({super.key, this.belowCard});

  /// Builds what sits directly under a curriculum's card (the shortfall
  /// warnings, Story 2.11 T4); nothing when null.
  final Widget Function(CurriculumForecast forecast)? belowCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final forecasts = ref.watch(parentForecastProvider);
    if (forecasts case AsyncError(:final error)) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 18),
        child: ForecastCardFrame(
          key: const Key('onTrackCardError'),
          child: InlineAsyncError(
            error: error,
            onRetry: () => retryLearnerForecast(ref),
          ),
        ),
      );
    }
    if (!forecasts.hasValue) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 18),
        child: Semantics(
          label: l10n.onTrackLoading,
          child: const ForecastCardFrame(
            key: Key('onTrackCardLoading'),
            child: SizedBox(height: 56),
          ),
        ),
      );
    }
    final list = forecasts.requireValue;
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final forecast in list) ...[
          OnTrackCard(forecast: forecast, showCurriculum: list.length > 1),
          if (belowCard != null) belowCard!(forecast),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

/// The on-track card of one curriculum.
class OnTrackCard extends ConsumerWidget {
  /// Creates the card.
  const OnTrackCard({
    super.key,
    required this.forecast,
    this.showCurriculum = false,
  });

  /// The engine values to show.
  final CurriculumForecast forecast;

  /// Whether to name the curriculum (more than one is forecast).
  final bool showCurriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final projection = forecast.projection;
    final view = forecast.onTrack;
    final deadline = projection.deadline;
    final lineStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.brandInk,
      fontWeight: FontWeight.w600,
    );

    // Under 14 days the engine makes no projection: "Too early to tell" is
    // the neutral status, with or without a deadline (UX-DR-94).
    final status =
        view.status ??
        (view.projectionTooEarly ? PaceReportStatus.tooEarly : null);
    final statusChip = switch (status) {
      PaceReportStatus.onTrack => _StatusChip(
        key: const Key('onTrackStatus'),
        icon: Icons.check_circle_rounded,
        label: l10n.onTrackOnTrack,
        foreground: colors.statusSuccessSoftText,
        background: colors.statusSuccessSoftBg,
      ),
      PaceReportStatus.behindPace => _StatusChip(
        key: const Key('onTrackStatus'),
        icon: Icons.warning_amber_rounded,
        label: l10n.onTrackBehindPace,
        foreground: colors.brandWarningDeep,
        background: colors.brandWarningSoft,
      ),
      PaceReportStatus.tooEarly => _StatusChip(
        key: const Key('onTrackStatus'),
        icon: Icons.hourglass_empty_rounded,
        label: l10n.onTrackTooEarly,
        foreground: colors.brandInkMuted,
        background: colors.brandCreamSoft,
      ),
      null => null,
    };

    // The projected finish, as the report shows it: none while the status
    // already says it is too early (UX-DR-94); "not enough recent learning"
    // when the engine has no finish date.
    final finish = projection.projectedFinish;
    String? projectionLine;
    if (finish != null || status != PaceReportStatus.tooEarly) {
      final finishText = finish == null
          ? l10n.onTrackFinishUnknown
          : formatForecastDate(context, finish);
      projectionLine = deadline == null
          ? l10n.onTrackProjectedFinish(finishText)
          : l10n.onTrackProjectedFinishWithDeadline(
              finishText,
              formatForecastDate(context, deadline),
            );
    }

    // FR-20: the mapping shows no daily target without a deadline (or a
    // calendar program), even if the engine derived one.
    final target = view.dailyTarget;
    String? targetLine;
    if (target != null) {
      targetLine = target == 0
          ? l10n.todayTargetAllCovered
          : l10n.onTrackDailyTarget(
              formatForecastCount(context, target),
              forecastLeafUnit(ref, l10n, forecast.curriculum, count: target),
            );
    }

    // A calendar program behind its calendar (DNI-518 AC-8).
    final behind = view.calendarShortfall;
    final behindLine = behind == null
        ? null
        : l10n.reportOnTrackCalendarBehind(
            formatForecastCount(context, behind),
            forecastLeafUnit(ref, l10n, forecast.curriculum, count: behind),
          );

    final lines = <Widget>[
      ?statusChip,
      if (projectionLine != null)
        _IconLine(
          key: const Key('onTrackProjection'),
          icon: Icons.event_available_rounded,
          text: projectionLine,
          style: lineStyle,
        ),
      if (targetLine != null)
        _IconLine(
          key: const Key('onTrackDailyTarget'),
          icon: Icons.speed_rounded,
          text: targetLine,
          style: lineStyle,
        ),
      if (behindLine != null)
        _IconLine(
          key: const Key('onTrackCalendarBehind'),
          icon: Icons.event_busy_rounded,
          text: behindLine,
          style: lineStyle?.copyWith(color: colors.brandWarningDeep),
          iconColor: colors.brandWarningDeep,
        ),
    ];

    return ForecastCardFrame(
      key: Key('onTrackCard-${forecast.curriculumId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCurriculum && forecast.curriculum != null) ...[
            CurriculumLabel.curriculum(
              forecast.curriculum!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.brandInkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= kForecastStatusRowMinWidth) {
                // Tablet status row: status · projected finish · target.
                return Wrap(
                  key: const Key('onTrackStatusRow'),
                  spacing: 24,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: lines,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, line) in lines.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    line,
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A status pill: icon plus text label (UX-DR-157).
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    container: true,
    excludeSemantics: true,
    child: _pill(context),
  );

  Widget _pill(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 12, 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: 18, color: foreground),
          ),
          const TextSpan(text: ' '),
          TextSpan(text: label),
        ],
      ),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// A line of text led by an icon; wraps instead of clipping at large text
/// and in Hebrew.
class _IconLine extends StatelessWidget {
  const _IconLine({
    super.key,
    required this.icon,
    required this.text,
    required this.style,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final TextStyle? style;

  /// The icon colour; `brandInkMuted` by default.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    container: true,
    excludeSemantics: true,
    child: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? context.colors.brandInkMuted,
            ),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: text),
        ],
      ),
      style: style,
    ),
  );
}
