import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/track_learning_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

final _trackGoalProvider = FutureProvider.autoDispose.family<Goal?, int>(
  (ref, trackId) =>
      ref.watch(userDatabaseProvider).goalDao.getGoalByTrack(trackId),
);

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
    final chazaraTerm = ref.watch(useHebrewTermsProvider)
        ? HebrewTerms.uiActiveTrackChazara
        : l10n.activeTrackChazaraLabel;

    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(track.id),
    );
    final cycleFraction = completionAsync.asData?.value ?? 0.0;
    final cyclePercentDisplay = formatFractionAsPercent(cycleFraction);

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
    final accent = trackAccentForType(track.trackType);
    final icon = trackTypeIconData(track.trackType);
    final trackLabel = trackTypeDisplayLabel(track.trackType);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
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
          _buildHeaderCard(
            context,
            theme,
            l10n,
            track,
            accent,
            icon,
            trackLabel,
            activatedDate,
            hasProgramEnrollment,
            cycleFraction,
            cyclePercentDisplay,
            curriculumBarColor,
            chazaraTerm,
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
    String trackLabel,
    String activatedDate,
    bool hasProgramEnrollment,
    double cycleFraction,
    String cyclePercentDisplay,
    Color curriculumBarColor,
    String chazaraTerm, {
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
            color: const Color(0xFF0A2056).withValues(alpha: 0.07),
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
                      trackLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.brandBlueDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
          if (!hasProgramEnrollment) ...[
            Row(
              children: [
                Text(
                  l10n.carouselCompletion(chazaraTerm),
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
          _configRow(theme, l10n.trackDetailConfigType, trackLabel),
          if (goal != null)
            _configRow(theme, l10n.trackDetailConfigGoal, _goalLabel(goal, l10n)),
          if (itemsRemaining != null)
            _configRow(theme, l10n.trackDetailConfigItemsRemaining, '$itemsRemaining'),
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

  String? _goalLabel(Goal? goal, AppLocalizations l10n) {
    if (goal == null) return null;
    if (goal.goalType == 'pace' &&
        goal.paceValue != null &&
        goal.pacePeriod != null) {
      final period =
          goal.pacePeriod == 'per_day' ? l10n.pacePerDay : l10n.pacePerWeek;
      return '${goal.paceValue} · $period';
    }
    if (goal.goalType == 'deadline' && goal.targetDate != null) {
      // Show the raw deadline date; the "Est. finish" row is not shown for
      // deadline goals to avoid repeating the same value twice.
      return DateFormat.yMMMd().format(goal.targetDate!.toLocal());
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
        return DateFormat.yMMMd(locale)
            .format(goal.createdAt.toLocal().add(Duration(days: days)));
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
            color: const Color(0xFF0A2056).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!hasProgramEnrollment) ...[
            ListTile(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              leading: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF1C47C4),
              ),
              title: Text(AppLocalizations.of(context)!.trackMarkContentDone),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: curriculum != null
                  ? () => _openBulkMark(track, curriculum)
                  : null,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.swap_vert_rounded,
                color: Color(0xFF1C47C4),
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
              color: Color(0xFF1C47C4),
            ),
            title: Text(AppLocalizations.of(context)!.trackEditLabel),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => EditTrackScreen(track: track),
              ),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
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
          awardGamificationPoints: true,
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
