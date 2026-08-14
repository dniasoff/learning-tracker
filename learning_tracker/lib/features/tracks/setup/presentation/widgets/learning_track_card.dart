import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
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

  final CurriculumTrackEntity track;
  final bool showProgress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = track.curriculumId;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(track.curriculumId),
    );
    final cycleFraction = completionAsync.value;
    final cyclePercentDisplay = completionAsync.hasValue
        ? formatFractionAsPercent(cycleFraction!)
        : null;

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
        ref.watch(trackHasChazaraProvider(track.curriculumId)).asData?.value ??
        false;

    // The "chazara" term renders per the Hebrew-terms preference: transliterated
    // in English, Hebrew script when the toggle is on (or in Hebrew locale).
    final chazaraTerm = domainTermLabels(ref).chazara;

    final hasProgramEnrollment =
        ref
            .watch(dashboardHasProgramEnrollmentProvider(curriculum))
            .asData
            ?.value ??
        false;

    final curriculumBarColor = context.colors.curriculumFor(curriculum);

    // W3.22: trackType column dropped — all tracks are now 'personal'.
    final accent = context.colors.blueMedium;
    const icon = Icons.menu_book_rounded;

    final cardTitle = trackDisplayTitle(ref, track);
    final progressSemantics = completionAsync.hasError
        ? l10n.errorWithMessage
        : completionAsync.isLoading
        ? l10n.loading
        : cyclePercentDisplay!;
    final semanticsLabel = showProgress && !hasProgramEnrollment
        ? '$cardTitle, $progressSemantics'
        : cardTitle;

    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.brandCreamCard,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: context.colors.blueDeepNavy.withValues(alpha: 0.07),
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
                      // B-EDIT-NAME fix: surface the user's custom track name
                      // (Goal.description) when set, falling back to the
                      // curriculum label. The card previously always showed the
                      // curriculum name and ignored an edited name.
                      Text(
                        trackDisplayTitle(ref, track),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: context.colors.brandBlueDeep,
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
                                  color: context.colors.brandInkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if (completionAsync.hasError)
                                InlineAsyncError(
                                  error: completionAsync.error!,
                                  onRetry: () => ref.invalidate(
                                    dashboardTrackCompletionPercentageProvider(
                                      track.curriculumId,
                                    ),
                                  ),
                                )
                              else if (completionAsync.isLoading)
                                SizedBox(
                                  width: 28,
                                  height: 12,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: context.colors.brandCreamSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  cyclePercentDisplay!,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: context.colors.brandInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (completionAsync.hasValue)
                            ExcludeSemantics(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: cycleFraction!,
                                  minHeight: 10,
                                  backgroundColor:
                                      context.colors.brandCreamSoft,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    curriculumBarColor,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 10),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 30,
                  color: context.colors.brandBlueDeep,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Rule-7 (no track types): the dead `trackTypeIconData` / `trackAccentForType`
// helpers — which switched on `'personal'`/`'school'`/`'advanced'` and were
// never called — were removed. All tracks are implicitly personal now.
