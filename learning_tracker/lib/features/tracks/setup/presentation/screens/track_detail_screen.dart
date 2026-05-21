import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_info_card.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

final _trackGoalProvider = FutureProvider.autoDispose.family<Goal?, int>(
  (ref, trackId) =>
      ref.watch(userDatabaseProvider).goalDao.getGoalByTrack(trackId),
);

/// Computes a [PaceCalculator] for the given [CurriculumTrack].
///
/// Live completions: `completedAt >= track.activatedAt` (excluding sentinel).
/// Bulk baseline: completions with the sentinel date (2000-01-01).
/// Total items: from [scopedItemCountProvider] (0 when curriculum unknown).
/// targetDate: deadline-goal date when available; otherwise today (so
///   requiredVelocity returns 0 — not meaningful for pace goals).
final _trackPaceCalcProvider = FutureProvider.autoDispose
    .family<PaceCalculator, CurriculumTrack>((ref, track) async {
      final db = ref.watch(userDatabaseProvider);
      final profileId = track.profileId;

      final allCompletions = await db.completionDao
          .getCompletionsByTrackAndProfile(track.id, profileId);

      final trackStart = track.activatedAt.toLocal();

      final liveCount = allCompletions
          .where(
            (c) =>
                !c.completedAt.isBefore(trackStart) &&
                !c.completedAt.isAtSameMomentAs(kBulkPriorSentinelDate),
          )
          .length;

      final bulkBaseline = allCompletions
          .where(
            (c) =>
                c.completedAt.isAtSameMomentAs(kBulkPriorSentinelDate) ||
                c.completedAt.isBefore(trackStart),
          )
          .length;

      final curriculum = CurriculumId.values
          .where((c) => c.storageKey == track.curriculumId)
          .firstOrNull;

      final totalItems = curriculum != null
          ? await ref.watch(scopedItemCountProvider(curriculum).future)
          : 0;

      final goal = await db.goalDao.getGoalByTrack(track.id);
      final clock = ref.watch(localDayClockProvider);
      final targetDate =
          (goal?.goalType == 'deadline' && goal?.targetDate != null)
          ? goal!.targetDate!.toLocal()
          : clock.today();

      final today = clock.today();

      return PaceCalculator.compute(
        totalItems: totalItems,
        bulkBaseline: bulkBaseline,
        liveProgress: liveCount,
        trackStartDate: trackStart,
        targetDate: targetDate,
        today: today,
      );
    });

@RoutePage()
class TrackDetailScreen extends ConsumerStatefulWidget {
  const TrackDetailScreen({super.key, required this.track});

  final CurriculumTrack track;

  @override
  ConsumerState<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends ConsumerState<TrackDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;
    final titleText = curriculum != null
        ? curriculumLabelText(ref, curriculum: curriculum)
        : track.curriculumId;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // The "chazara" term renders per the Hebrew-terms preference: transliterated
    // in English, Hebrew script when the toggle is on (or in Hebrew locale).
    final chazaraTerm = domainTermLabels(ref).chazara;
    final trackHasChazara =
        ref.watch(trackHasChazaraProvider(track.id)).asData?.value ?? false;

    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(track.id),
    );
    final cycleFraction = completionAsync.asData?.value ?? 0.0;
    final cyclePercentDisplay = formatFractionAsPercent(cycleFraction);

    // W5-B (Task #16): dual-progress labels — Track progress (current cycle)
    // and Lifetime (all-time) — sourced from [trackDualProgressMetricsProvider]
    // so the Track Detail header matches the same numbers shown on the
    // Dashboard active-track card and the Progress hub per-track rows.
    final dualMetricsAsync = ref.watch(
      trackDualProgressMetricsProvider(track.profileId),
    );
    final dualMetricMatches = dualMetricsAsync.asData?.value
        .where((m) => m.trackId == track.id)
        .toList();
    final dualMetric = (dualMetricMatches == null || dualMetricMatches.isEmpty)
        ? null
        : dualMetricMatches.first;
    final currentCyclePct = dualMetric?.currentCyclePercentage ?? 0.0;
    final lifetimePct = dualMetric?.lifetimePercentage ?? 0.0;
    final trackProgressDisplay = dualMetricsAsync.isLoading
        ? '…'
        : formatFractionAsPercent(currentCyclePct);
    final lifetimeDisplay = dualMetricsAsync.isLoading
        ? '…'
        : formatFractionAsPercent(lifetimePct);

    final hasProgramEnrollment = curriculum != null
        ? (ref
                  .watch(dashboardHasProgramEnrollmentProvider(curriculum))
                  .asData
                  ?.value ??
              false)
        : false;

    final curriculumBarColor = AppTheme.getCurriculumColorByKey(
      track.curriculumId,
    );
    // W3.22: trackType column dropped — all tracks are now 'personal'.
    const accent = AppColors.blueMedium;
    const icon = Icons.menu_book_rounded;
    final locale = Localizations.localeOf(context).toString();
    final activatedDate = DateFormat.yMMMd(locale).format(track.activatedAt);

    final goal = ref.watch(_trackGoalProvider(track.id)).asData?.value;
    final totalScopeAsync = curriculum != null
        ? ref.watch(scopedItemCountProvider(curriculum))
        : null;
    final totalScope = totalScopeAsync?.asData?.value;
    final itemsRemaining = totalScope != null
        ? (totalScope * (1 - cycleFraction)).ceil().clamp(0, totalScope)
        : null;
    final estimatedFinish = _estimatedFinish(goal, itemsRemaining, locale);

    final useHebrewCalendar = ref.watch(useHebrewDateProvider);
    final paceCalc = ref.watch(_trackPaceCalcProvider(track)).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.surfaceF5,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceF5,
        elevation: 0,
        title: Text(
          titleText,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandBlueDeep,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TrackInfoCard(
            track: track,
            goal: goal,
            paceCalc: paceCalc,
            useHebrewCalendar: useHebrewCalendar,
          ),
          const SizedBox(height: 16),
          _buildHeaderCard(
            context,
            theme,
            l10n,
            track,
            accent,
            icon,
            activatedDate,
            hasProgramEnrollment,
            cycleFraction,
            cyclePercentDisplay,
            curriculumBarColor,
            chazaraTerm,
            trackProgressLabel: l10n.trackProgress,
            trackProgressDisplay: trackProgressDisplay,
            lifetimeLabel: l10n.lifetimeLabel,
            lifetimeDisplay: lifetimeDisplay,
            trackHasChazara: trackHasChazara,
            locale: locale,
            goal: goal,
            itemsRemaining: itemsRemaining,
            estimatedFinish: estimatedFinish,
          ),
          const SizedBox(height: 20),
          _buildActionsCard(
            context,
            theme,
            track,
            curriculum,
            hasProgramEnrollment: hasProgramEnrollment,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    CurriculumTrack track,
    Color accent,
    IconData icon,
    String activatedDate,
    bool hasProgramEnrollment,
    double cycleFraction,
    String cyclePercentDisplay,
    Color curriculumBarColor,
    String chazaraTerm, {
    required String trackProgressLabel,
    required String trackProgressDisplay,
    required String lifetimeLabel,
    required String lifetimeDisplay,
    required bool trackHasChazara,
    required String locale,
    Goal? goal,
    int? itemsRemaining,
    String? estimatedFinish,
  }) {
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
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.trackSince(activatedDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // W5-B (Task #16): dual progress labels — Track progress (current
          // cycle since activation) and Lifetime (all-time tier). These two
          // numbers must always be visible so the user can distinguish
          // "this cycle" engagement from total knowledge accumulated.
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '$trackProgressLabel: $trackProgressDisplay',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$lifetimeLabel: $lifetimeDisplay',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasProgramEnrollment) ...[
            Row(
              children: [
                Text(
                  trackHasChazara
                      ? l10n.carouselCompletion(chazaraTerm)
                      : trackProgressLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  cyclePercentDisplay,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: cycleFraction,
                minHeight: 10,
                backgroundColor: AppTheme.brandCreamSoft,
                valueColor: AlwaysStoppedAnimation<Color>(curriculumBarColor),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEF0F6)),
          const SizedBox(height: 14),
          if (goal != null)
            _configRow(
              theme,
              l10n.trackDetailConfigGoal,
              _goalLabel(goal, l10n, locale),
            ),
          if (itemsRemaining != null)
            _configRow(
              theme,
              l10n.trackDetailConfigItemsRemaining,
              '$itemsRemaining',
            ),
          if (estimatedFinish != null)
            _configRow(theme, l10n.trackDetailConfigEstFinish, estimatedFinish),
        ],
      ),
    );
  }

  Widget _configRow(ThemeData theme, String label, String? value) {
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
            value ?? '—',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _goalLabel(Goal? goal, AppLocalizations l10n, String locale) {
    if (goal == null) return null;
    if (goal.goalType == 'pace' &&
        goal.paceValue != null &&
        goal.pacePeriod != null) {
      final period = goal.pacePeriod == 'per_day'
          ? l10n.pacePerDay
          : l10n.pacePerWeek;
      return '${goal.paceValue} · $period';
    }
    if (goal.goalType == 'deadline' && goal.targetDate != null) {
      // Show the raw deadline date; the "Est. finish" row is not shown for
      // deadline goals to avoid repeating the same value twice.
      return DateFormat.yMMMd(locale).format(goal.targetDate!.toLocal());
    }
    return null;
  }

  String? _estimatedFinish(Goal? goal, int? itemsRemaining, String locale) {
    if (goal == null) return null;
    // Deadline goals surface their date in the "Goal" row; skip here.
    if (goal.goalType == 'deadline') return null;
    if (goal.goalType == 'pace' &&
        goal.paceValue != null &&
        goal.pacePeriod != null &&
        itemsRemaining != null &&
        itemsRemaining > 0) {
      final weeklyRate = goal.pacePeriod == 'per_day'
          ? goal.paceValue! * 7
          : goal.paceValue!;
      if (weeklyRate > 0) {
        final days = (itemsRemaining / weeklyRate * 7).ceil();
        return DateFormat.yMMMd(
          locale,
        ).format(goal.createdAt.toLocal().add(Duration(days: days)));
      }
    }
    return null;
  }

  Widget _buildActionsCard(
    BuildContext context,
    ThemeData theme,
    CurriculumTrack track,
    CurriculumId? curriculum, {
    required bool hasProgramEnrollment,
  }) {
    // Mark Content Done + Reorder Content are self-paced-only. When the
    // user is following a program (Daf Yomi, Mishna Yomi, etc.) the
    // pace and order are dictated by the program, so showing those
    // controls is misleading.
    return DecoratedBox(
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
        children: [
          if (!hasProgramEnrollment) ...[
            // W5-B (Task #16): Bulk-prior path — visually differentiated
            // from a "Mark complete" (live) action with outlined/secondary
            // styling so users can't confuse historical/lifetime marking
            // with live completion (which credits engagement). The icon and
            // foreground colour both use the secondary outline treatment.
            // Copy hardcoded English for now — l10n sweep follows.
            ListTile(
              key: const ValueKey('trackDetail.bulkPriorTile'),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                side: BorderSide(
                  color: AppColors.blueMedium.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              tileColor: AppColors.blueMedium.withValues(alpha: 0.06),
              leading: const Icon(
                Icons.history_edu_outlined,
                color: AppColors.blueMedium,
              ),
              title: Text(
                AppLocalizations.of(context)!.trackMarkPreviouslyLearned,
                style: const TextStyle(color: AppColors.blueMedium),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.blueMedium,
              ),
              onTap: curriculum != null
                  ? () => _openBulkMark(track, curriculum)
                  : null,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.swap_vert_rounded,
                color: AppColors.blueMedium,
              ),
              title: Text(AppLocalizations.of(context)!.trackReorderContent),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: curriculum != null
                  ? () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TrackLearningOrderScreen(
                          trackId: track.id,
                          curriculumId: curriculum,
                        ),
                      ),
                    )
                  : null,
            ),
            const Divider(height: 1, indent: 56),
          ],
          ListTile(
            shape: hasProgramEnrollment
                ? const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  )
                : null,
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.blueMedium,
            ),
            title: Text(AppLocalizations.of(context)!.trackEditLabel),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => EditTrackScreen(track: track)),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            leading: Icon(
              Icons.delete_outline_rounded,
              color: theme.colorScheme.error,
            ),
            title: Text(
              AppLocalizations.of(context)!.trackDeleteLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.error,
            ),
            onTap: () => _showDeleteDialog(track, curriculum),
          ),
        ],
      ),
    );
  }

  Future<void> _openBulkMark(
    CurriculumTrack track,
    CurriculumId curriculum,
  ) async {
    final navigator = Navigator.of(context);
    final scopes = await ref
        .read(userDatabaseProvider)
        .curriculumScopeDao
        .getScopesByTrack(track.id);
    final scopeEntries = scopes
        .map((s) => ScopeEntry(level: s.scopeLevel, value: s.scopeValue))
        .toList();

    if (!mounted) return;
    await navigator.push<BulkMarkResult>(
      MaterialPageRoute(
        builder: (_) => BulkMarkScreen(
          curriculumId: curriculum,
          scopeConstraints: scopeEntries.isEmpty ? null : scopeEntries,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    CurriculumTrack track,
    CurriculumId? curriculum,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // 'archive' = keep history; 'wipe' = hard-delete completions; null = cancel
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTrackArchiveTitle),
        content: Text(l10n.deleteTrackArchiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'archive'),
            child: Text(l10n.deleteTrackArchive),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, 'wipe'),
            child: Text(l10n.deleteTrackWipe),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    final dao = ref.read(userDatabaseProvider).trackDao;
    if (choice == 'wipe') {
      await dao.purgeHistory(track.id);
    } else {
      await dao.deleteTrackAndData(track.id);
    }
    await onTrackChanged(ref, track.profileId);
    if (mounted) context.router.pop();
  }
}
