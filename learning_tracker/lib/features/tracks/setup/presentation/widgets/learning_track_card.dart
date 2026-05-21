import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Rich track row used on [TrackManagementHubScreen] and
/// [ParentTrackManagementScreen] (same visual design).
///
/// **Completion** (stage/cycle) matches [dashboardTrackCompletionPercentageProvider]
/// when not on a program track.
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

    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(track.id),
    );
    final cycleFraction = completionAsync.asData?.value ?? 0.0;
    final cyclePercentDisplay = formatFractionAsPercent(cycleFraction);

    // Per-track chazara gate: only render the chazara-aware label when this
    // track actually has chazara stages. Tracks without chazara show a neutral
    // "Track progress" label — never "Completion (with חזרה)".
    //
    // Loading default is `false` (chazara-neutral) so a learn-only track
    // NEVER briefly shows a chazara reference — the strict rule
    // (`feedback_chazara_conditional_rendering`) wins over the chazara
    // track's brief "Track progress" → "Completion (with חזרה)" flicker
    // on first mount.
    final trackHasChazara =
        ref.watch(trackHasChazaraProvider(track.id)).asData?.value ?? false;

    // The "chazara" term renders per the Hebrew-terms preference: transliterated
    // in English, Hebrew script when the toggle is on (or in Hebrew locale).
    final chazaraTerm = domainTermLabels(ref).chazara;

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
                color: AppColors.blueDeepNavy.withValues(alpha: 0.07),
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
                child: const Icon(icon, color: Colors.white, size: 34),
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
                    if (showProgress) ...[
                      const SizedBox(height: 9),
                      if (!hasProgramEnrollment) ...[
                        Row(
                          children: [
                            Text(
                              trackHasChazara
                                  ? l10n.carouselCompletion(chazaraTerm)
                                  : l10n.trackProgress,
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

Color trackAccentForType(String trackType) {
  return switch (trackType) {
    'personal' => AppColors.blueMedium,
    'school' => const Color(0xFFBC8105),
    'advanced' => const Color(0xFF0EAE81),
    _ => AppTheme.brandBlue,
  };
}
