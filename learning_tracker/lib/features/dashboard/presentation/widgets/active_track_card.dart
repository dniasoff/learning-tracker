import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_focus_pill.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_stat_grid.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

CurriculumId _curriculumIdForTrack(CurriculumTrack track) {
  return CurriculumId.values.firstWhere(
    (c) => c.storageKey == track.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );
}

/// Active track card: program (task metrics) vs self-paced (completion) layouts.
class ActiveTrackCard extends ConsumerWidget {
  final CurriculumTrack track;
  final List<DailyTask> allTasks;

  const ActiveTrackCard({super.key, required this.track, required this.allTasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final curriculum = _curriculumIdForTrack(track);
    final hebrewOnly = ref.watch(useHebrewTermsProvider);
    final displayNamePrimary =
        '${_trackTypeLabelText(ref, track.trackType)} · '
        '${curriculumLabelText(ref, curriculum: curriculum)}';
    final displayNameSecondary = hebrewOnly
        ? null
        : curriculumHebrewName(curriculum);
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final bookIconBg = Color.lerp(
      kActiveTrackPrimaryBlue.withValues(alpha: 0.2),
      curriculumColor.withValues(alpha: 0.2),
      0.45,
    )!;
    final hasProgramEnrollmentAsync = ref.watch(
      dashboardHasProgramEnrollmentProvider(curriculum),
    );
    final profileId = ref.watch(activeProfileIdProvider);
    final lifetimeSummariesAsync = ref.watch(
      globalLifetimeCurriculaProvider(profileId),
    );
    final lifetimeFraction = lifetimeSummariesAsync.when(
      data: (summaries) {
        for (final s in summaries) {
          if (s.curriculumId == curriculum) return s.percentage;
        }
        return 0.0;
      },
      loading: () => null,
      error: (_, __) => 0.0,
    );
    final lifetimePercentDisplay = lifetimeFraction == null
        ? '…'
        : formatFractionAsPercent(lifetimeFraction);

    final curriculumTasks = allTasks
        .where((t) => t.trackId == track.id)
        .toList();
    final hasProgramEnrollment =
        hasProgramEnrollmentAsync.asData?.value ?? false;
    final todayTask = hasProgramEnrollment
        ? programTrackFocusTask(curriculumTasks)
        : (curriculumTasks.isNotEmpty ? curriculumTasks.first : null);
    final taskBuckets = bucketTrackTasks(curriculumTasks);
    final focusLabel = hasProgramEnrollment
        ? l10n.activeTrackNextTask
        : l10n.activeTrackCurrentFocus;
    final focusRef = todayTask?.contentItemSefariaRef;
    // Renderer-driven: same path as reader, browse rows, daily task card.
    final focusValue = focusRef == null
        ? l10n.noProjection
        : (ref.watch(renderedDisplayForRefProvider(focusRef)).asData?.value ??
              focusRef);
    final lifetimeFull =
        lifetimeFraction != null && (lifetimeFraction - 1.0).abs() < 1e-6;

    return Card(
      elevation: 5,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      color: AppTheme.brandCreamCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          // Card-level tap: prefer the current-focus text when there is one
          // (matches the visible 'CURRENT FOCUS' label). Browse-tree fallback
          // only when nothing is scheduled.
          final focusRef = todayTask?.contentItemSefariaRef;
          if (focusRef != null && focusRef.isNotEmpty) {
            context.router.push(TextDisplayRoute(sefariaRef: focusRef));
          } else {
            context.router.push(
              ContentHierarchyRoute(curriculumId: curriculum.storageKey),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayNamePrimary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (displayNameSecondary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            displayNameSecondary,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bookIconBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: kActiveTrackPrimaryBlue,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ActiveTrackFocusPill(label: focusLabel, value: focusValue),
              const SizedBox(height: 10),
              TrackStatGrid(
                buckets: taskBuckets,
                l10n: l10n,
                chazaraLabel: ref.watch(useHebrewTermsProvider)
                    ? HebrewTerms.uiActiveTrackChazara
                    : l10n.activeTrackMetricChazara,
              ),
              if (taskBuckets.total == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.nothingDueInQueue,
                    maxLines: 2,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      height: 1.2,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.trackLifetimeLearning} • $lifetimePercentDisplay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (lifetimeFraction == null)
                          const SizedBox.shrink()
                        else
                          Icon(
                            lifetimeFull
                                ? Icons.check_circle_rounded
                                : Icons.show_chart_rounded,
                            size: 20,
                            color: lifetimeFull
                                ? kActiveTrackCompletionGreen
                                : AppTheme.brandInkMuted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        // If there's a concrete next-task / current focus,
                        // jump straight to its text — that's what the
                        // 'CURRENT FOCUS' label promised. Fall back to the
                        // Learn tab when there's nothing scheduled.
                        final focusRef = todayTask?.contentItemSefariaRef;
                        if (focusRef != null && focusRef.isNotEmpty) {
                          context.router.push(
                            TextDisplayRoute(sefariaRef: focusRef),
                          );
                        } else {
                          context.router.navigate(const LearningRoute());
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kActiveTrackPrimaryBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      child: Text(l10n.continueCta),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _trackTypeLabelText(WidgetRef ref, String trackTypeStorageKey) {
  try {
    return trackTypeLabelText(
      ref,
      trackType: TrackType.fromStorageKey(trackTypeStorageKey),
    );
  } on Object {
    return trackTypeStorageKey;
  }
}
