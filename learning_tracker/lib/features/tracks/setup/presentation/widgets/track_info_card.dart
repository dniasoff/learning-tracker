import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Returns the VALUE string for the "Elapsed" info row.
///
/// TS-9 fix: the old [TrackInfoCard._elapsedRemainingLabel] prepended
/// `l10n.trackInfoElapsed` to the string, duplicating the row label.
/// The value must be just "N days [· Remaining M days]".
String elapsedRemainingLabel({
  required AppLocalizations l10n,
  required int elapsedDays,
  required int? remainingDays,
}) {
  // TS-9: do NOT prepend l10n.trackInfoElapsed here — the row label
  // already shows it.  Value = "$elapsedDays days [· Remaining M days]".
  final elapsedStr = '$elapsedDays ${l10n.trackInfoDays}';
  final remainingStr = remainingDays != null && remainingDays >= 0
      ? '${l10n.trackInfoRemaining} $remainingDays ${l10n.trackInfoDays}'
      : null;
  return remainingStr != null ? '$elapsedStr · $remainingStr' : elapsedStr;
}

/// Info card shown at the TOP of the Track Detail screen, surfacing key pace
/// and timeline metrics: started date, goal date, required & actual pace, and
/// elapsed / remaining day counts.
class TrackInfoCard extends ConsumerWidget {
  const TrackInfoCard({
    super.key,
    required this.track,
    required this.goal,
    required this.paceCalc,
    required this.useHebrewCalendar,
  });

  final CurriculumTrack track;

  /// Nullable — no goal has been set for this track yet.
  final Goal? goal;

  /// Pre-computed pace metrics for the track.
  final PaceCalculator? paceCalc;

  /// When true, dates are rendered using the Hebrew calendar formatter.
  final bool useHebrewCalendar;

  // ---------------------------------------------------------------------------
  // Date formatting helpers
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime date, String locale) {
    final local = date.toLocal();
    if (useHebrewCalendar) {
      return HebrewCalendarUtils.gregorianToHebrew(local);
    }
    return DateFormat.yMMMd(locale).format(local);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    final today = ref.watch(localDayClockProvider).today();
    final startedLocal = track.activatedAt.toLocal();

    final elapsedDays = today.difference(startedLocal).inDays;

    final targetDate = goal?.targetDate?.toLocal();
    final remainingDays = targetDate?.difference(today).inDays;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueDeepNavy.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Started ─────────────────────────────────────────────────────
          _infoRow(
            theme,
            label: l10n.trackInfoStarted,
            value: _formatDate(track.activatedAt, locale),
          ),

          // ── Goal date (deadline goals only) ──────────────────────────────
          if (goal != null && goal!.targetDate != null)
            _infoRow(
              theme,
              label: l10n.trackInfoGoal,
              value: _formatDate(goal!.targetDate!, locale),
            ),

          // ── Required pace ─────────────────────────────────────────────────
          if (goal != null)
            _infoRow(
              theme,
              label: l10n.trackInfoRequiredPace,
              value: _requiredPaceLabel(l10n, goal!, paceCalc, today),
            ),

          // ── Actual pace ───────────────────────────────────────────────────
          _infoRowWithCaption(
            theme,
            label: l10n.trackInfoActualPace,
            value: _actualPaceLabel(l10n, paceCalc),
            caption: l10n.trackInfoActualPaceCaption,
          ),

          // ── Elapsed / Remaining ───────────────────────────────────────────
          _infoRow(
            theme,
            label: l10n.trackInfoElapsed,
            value: _elapsedRemainingLabel(l10n, elapsedDays, remainingDays),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Value builders
  // ---------------------------------------------------------------------------

  String _requiredPaceLabel(
    AppLocalizations l10n,
    Goal goal,
    PaceCalculator? paceCalc,
    DateTime today,
  ) {
    if (goal.goalType == 'deadline') {
      if (paceCalc == null ||
          paceCalc.requiredVelocity == 0 ||
          (goal.targetDate != null && goal.targetDate!.isBefore(today))) {
        return '—';
      }
      return '${paceCalc.requiredVelocity.toStringAsFixed(1)} '
          '${l10n.trackInfoItemsPerDay}';
    }
    // Pace goal — show the user's stated target.
    if (goal.paceValue != null && goal.pacePeriod != null) {
      final periodLabel = goal.pacePeriod == 'per_day'
          ? l10n.pacePerDay
          : l10n.pacePerWeek;
      return '${goal.paceValue} · $periodLabel';
    }
    return '—';
  }

  String _actualPaceLabel(AppLocalizations l10n, PaceCalculator? paceCalc) {
    if (paceCalc == null || paceCalc.actualVelocity == 0) return '—';
    return '${paceCalc.actualVelocity.toStringAsFixed(1)} '
        '${l10n.trackInfoItemsPerDay}';
  }

  // TS-9 fix: delegate to the top-level [elapsedRemainingLabel] so the
  // value does not repeat the row label text.
  String _elapsedRemainingLabel(
    AppLocalizations l10n,
    int elapsedDays,
    int? remainingDays,
  ) => elapsedRemainingLabel(
    l10n: l10n,
    elapsedDays: elapsedDays,
    remainingDays: remainingDays,
  );

  // ---------------------------------------------------------------------------
  // Row widgets (mirror the _configRow pattern used in the header card)
  // ---------------------------------------------------------------------------

  Widget _infoRow(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithCaption(
    ThemeData theme, {
    required String label,
    required String value,
    required String caption,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
