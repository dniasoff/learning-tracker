import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/track_learning_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
    final profileId = ref.watch(activeProfileIdProvider);
    final theme = Theme.of(context);

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

    final lifetimeSummaryAsync = curriculum != null
        ? ref.watch(
            lifetimeDataProvider((
              profileId: profileId,
              curriculumId: curriculum,
            )),
          )
        : null;
    final lifetimeFraction = lifetimeSummaryAsync?.when(
      data: (summary) => summary?.percentage ?? 0.0,
      loading: () => null,
      error: (_, __) => 0.0,
    );
    final lifetimeProgress = lifetimeFraction ?? 0.0;
    final lifetimePercentDisplay = lifetimeFraction == null
        ? '…'
        : formatFractionAsPercent(lifetimeFraction);

    final curriculumBarColor = AppTheme.getCurriculumColorByKey(
      track.curriculumId,
    );
    final accent = trackAccentForType(track.trackType);
    final icon = trackTypeIconData(track.trackType);
    final trackLabel = trackTypeDisplayLabel(track.trackType);
    final activatedDate = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(track.activatedAt);

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
            lifetimeProgress,
            lifetimePercentDisplay,
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
    double lifetimeProgress,
    String lifetimePercentDisplay,
  ) {
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
                  l10n.carouselCompletion,
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
          Row(
            children: [
              Text(
                l10n.trackLifetimeLearning,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                lifetimePercentDisplay,
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
              value: lifetimeProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8ECF3),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2CC597),
              ),
            ),
          ),
        ],
      ),
    );
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
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
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
    final name = curriculum != null
        ? curriculumLabelText(ref, curriculum: curriculum)
        : track.curriculumId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.trackDeleteTitle),
        content: Text(AppLocalizations.of(context)!.trackDeleteContent(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.actionDelete),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      await ref
          .read(userDatabaseProvider)
          .trackDao
          .deleteTrackAndData(track.id);
      await onTrackChanged(ref, track.profileId);
      if (mounted) context.router.pop();
    }
  }
}
