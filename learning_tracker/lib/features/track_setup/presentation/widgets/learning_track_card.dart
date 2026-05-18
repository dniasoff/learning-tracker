import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Rich track row used on [TrackManagementHubScreen] and
/// [ParentTrackManagementScreen] (same visual design).
///
/// **Completion** (stage/cycle) matches [dashboardTrackCompletionPercentageProvider]
/// when not on a program track. **Lifetime learning** uses
/// [lifetimeDataProvider] / [CurriculumLifetimeSummary.percentage] —
/// same per-curriculum % as Settings → Add what you've learned.
class LearningTrackCard extends ConsumerWidget {
  const LearningTrackCard({
    super.key,
    required this.track,
    this.showProgress = false,
    this.onTap,
    this.onLongPress,
  });

  final CurriculumTrack track;
  final bool showProgress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    CurriculumId? curriculum;
    for (final c in CurriculumId.values) {
      if (c.storageKey == track.curriculumId) {
        curriculum = c;
        break;
      }
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final profileId = ref.watch(activeProfileIdProvider);

    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(track.id),
    );
    final cycleFraction = completionAsync.asData?.value ?? 0.0;
    final cyclePercentDisplay = formatFractionAsPercent(cycleFraction);

    // The "chazara" term renders per the Hebrew-terms preference: transliterated
    // in English, Hebrew script when the toggle is on (or in Hebrew locale).
    final chazaraTerm = ref.watch(useHebrewTermsProvider)
        ? HebrewTerms.uiActiveTrackChazara
        : l10n.activeTrackChazaraLabel;

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A2056).withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (curriculum != null)
                      CurriculumLabel.curriculum(
                        curriculum,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.brandBlueDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Text(
                        track.curriculumId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.brandBlueDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      trackLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 9),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              curriculumBarColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 30,
                color: AppTheme.brandBlueDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData trackTypeIconData(String trackType) {
  return switch (trackType) {
    'personal' => Icons.menu_book_rounded,
    'school' => Icons.auto_awesome_rounded,
    'advanced' => Icons.verified_rounded,
    _ => Icons.menu_book_rounded,
  };
}

String trackTypeDisplayLabel(String trackType) {
  return switch (trackType) {
    'personal' => 'Personal Track',
    'school' => 'School Track',
    'advanced' => 'Advanced Track',
    _ => 'Learning Track',
  };
}

Color trackAccentForType(String trackType) {
  return switch (trackType) {
    'personal' => const Color(0xFF1C47C4),
    'school' => const Color(0xFFBC8105),
    'advanced' => const Color(0xFF0EAE81),
    _ => AppTheme.brandBlue,
  };
}
