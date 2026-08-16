import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/services/study_day_toggle_service.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Day labels in display order: Sunday first (ISO weekday 7), then Mon(1)..Sat(6).
const _displayOrder = [7, 1, 2, 3, 4, 5, 6];

/// Returns the localized short weekday label for a non-Saturday day.
///
/// Saturday (ISO 6) is handled separately by [studyDayLabel] via the
/// Nusach/Hebrew-Terms resolver — never from this function — to fix TS-4.
/// All other days are routed through the ARB so the Hebrew locale renders
/// proper Hebrew short day names (א׳, ב׳ …) instead of English Mon/Tue.
String _localizedDayAbbrev(AppLocalizations l10n, int isoWeekday) {
  switch (isoWeekday) {
    case 7:
      return l10n.schedulerDayAbbrevSun;
    case 1:
      return l10n.schedulerDayAbbrevMon;
    case 2:
      return l10n.schedulerDayAbbrevTue;
    case 3:
      return l10n.schedulerDayAbbrevWed;
    case 4:
      return l10n.schedulerDayAbbrevThu;
    case 5:
      return l10n.schedulerDayAbbrevFri;
    // 6 intentionally absent — resolved via shabbos() in [studyDayLabel].
    default:
      return '?';
  }
}

/// Returns the display label for a day of the week in the Study Days screen.
///
/// TS-4 fix: Saturday (ISO weekday 6) is routed through [DomainTermLabels.shabbos]
/// so it renders "Shabbos" (Ashkenazi), "Shabbat" (Sephardi), or "שבת" (Hebrew
/// mode). All other days use the localized short weekday labels so the Hebrew
/// locale shows proper Hebrew day names rather than English abbreviations.
String studyDayLabel({
  required int isoWeekday,
  required AppLocalizations l10n,
  required DomainTermLabels terms,
  required TransliterationVariant variant,
}) {
  if (isoWeekday == 6) {
    return terms.shabbos(variant: variant);
  }
  return _localizedDayAbbrev(l10n, isoWeekday);
}

@RoutePage()
class StudyDayConfigScreen extends ConsumerWidget {
  final CurriculumId curriculumId;

  const StudyDayConfigScreen({super.key, required this.curriculumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(studyDayConfigsProvider(curriculumId));
    final theme = Theme.of(context);
    // Resolve the curriculum's active track to gate the chazara/review UI.
    // Per the per-track chazara rule, a learn-only track must not show any
    // chazara/review references — body copy, legend, or the review-day toggle.
    final trackChazaraAsync = ref.watch(
      curriculumTrackHasChazaraProvider(curriculumId),
    );
    final trackHasChazara = trackChazaraAsync.asData?.value ?? false;

    // WS3.3d carry-forward: when a tutor has entered a talmid's context, gate
    // study-day editing behind `canEditStudyDays`. Owners (non-tutored context)
    // always edit. Mirrors the gating in parent_settings_screen.
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final canEdit = tutorPerms == null || tutorPerms.canEditStudyDays;

    // TS-4: read terms + variant so Saturday routes through nusach resolver.
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: l10n.schedulerStudyDaysScreenTitle(
            curriculumLabelText(ref, curriculum: curriculumId),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.router.maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: configAsync.when(
          data: (configs) {
            // Build a map of dayOfWeek -> DayType from current configs
            final dayTypeMap = <int, DayType>{};
            for (final config in configs) {
              dayTypeMap[config.dayOfWeek] = config.dayType;
            }

            // No chazara on this track → review-day configuration is moot.
            // Show a chazara-neutral message and skip the toggle entirely.
            // The message itself must NOT mention "review" or "chazara"
            // (per the per-track chazara rule — those terms are hidden
            // anywhere on a learn-only track, including this fallback).
            if (!trackHasChazara) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    l10n.schedulerStudyDaysAllStudyDays,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.schedulerStudyDaysIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Wrap (not Row) so the two legend chips flow to a second
                  // line on narrow widths / large text instead of overflowing.
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _LegendDot(
                        color: theme.colorScheme.primary,
                        label: AppLocalizations.of(
                          context,
                        )!.schedulerStudyLabel,
                      ),
                      _LegendDot(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        label: AppLocalizations.of(
                          context,
                        )!.schedulerReviewOnlyLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Day toggle grid
                  ...List.generate(_displayOrder.length, (index) {
                    final dow = _displayOrder[index];
                    final currentType =
                        dayTypeMap[dow] ?? DayType.study; // default study
                    final isStudy = currentType == DayType.study;

                    return _DayToggleTile(
                      // TS-4: use studyDayLabel so Saturday reads
                      // "Shabbos"/"Shabbat"/"שבת" per nusach + terms.
                      dayLabel: studyDayLabel(
                        isoWeekday: dow,
                        l10n: l10n,
                        terms: terms,
                        variant: variant,
                      ),
                      isStudy: isStudy,
                      onToggle: canEdit
                          ? () => _toggleDay(
                              context,
                              ref,
                              dow,
                              isStudy ? DayType.review : DayType.study,
                            )
                          : null,
                    );
                  }),
                  const SizedBox(height: 24),
                  // Summary + zero-study-day guard.
                  Builder(
                    builder: (context) {
                      final studyCount = _displayOrder
                          .where(
                            (dow) =>
                                (dayTypeMap[dow] ?? DayType.study) ==
                                DayType.study,
                          )
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              l10n.schedulerStudyDaysPerWeek(studyCount),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          // Inline warning when zero study days are selected:
                          // the week is entirely review-only and no new
                          // learning will be scheduled.
                          if (studyCount == 0) ...[
                            const SizedBox(height: 16),
                            _ZeroStudyDaysWarning(
                              message: l10n.schedulerStudyDaysZeroWarning,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => ref.refresh(studyDayConfigsProvider(curriculumId)),
          ),
        ),
      ),
    );
  }

  void _toggleDay(
    BuildContext context,
    WidgetRef ref,
    int dayOfWeek,
    DayType newType,
  ) {
    final adapter = ref.read(studyDayConfigRepositoryAdapterProvider);
    // STUDYDAY-TOGGLE-RACE-14: writeThenInvalidate guarantees the
    // scheduler invalidation runs strictly AFTER the write completes, so
    // allDailyTasksProvider re-reads the updated study-day config instead
    // of rebuilding from stale data.
    //
    // AUD-scheduler-17 (EH-2/EH-3): writeThenInvalidateGuarded catches a
    // thrown setDayConfig (not-ready backend, permission-denied) instead of
    // letting it propagate as an unhandled Future error, logs it via
    // AppLogger, and only invokes ref.invalidate when the widget is still
    // mounted — matching the context.mounted guard the SnackBar below
    // already uses.
    writeThenInvalidateGuarded(
      write: () => adapter.setDayConfig(
        curriculumId: curriculumId,
        dayOfWeek: dayOfWeek,
        dayType: newType,
      ),
      invalidate: () => ref.invalidate(allDailyTasksProvider),
      isMounted: () => context.mounted,
      onError: (e, st) {
        AppLogger.instance.error(
          event: 'study_day_toggle_write_failed',
          exception: e,
          stackTrace: st,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.schedulerStudyDayToggleSaveError,
              ),
            ),
          );
        }
      },
    );
  }
}

/// True when the active-profile curriculum track for [curriculumId] has
/// more than one stage (i.e. chazara is enabled). Keyed by curriculum
/// rather than trackId because this screen receives only a curriculumId.
///
/// Package-visible (not private) so regression tests can drive it directly
/// via a `ProviderContainer` instead of re-deriving `count > 1` inline
/// (AUD-t-scheduler-02 / STUDYDAY-CHAZARA-GATE-12).
final curriculumTrackHasChazaraProvider = FutureProvider.autoDispose
    .family<bool, CurriculumId>((ref, curriculumId) async {
      final stageRepository = ref.watch(globalStageRepositoryProvider);
      final stages = await stageRepository.getStagesForCurriculum(curriculumId);
      return stages.length > 1;
    });

class _DayToggleTile extends StatelessWidget {
  const _DayToggleTile({
    required this.dayLabel,
    required this.isStudy,
    required this.onToggle,
  });

  final String dayLabel;
  final bool isStudy;

  /// When `null`, the tile is read-only — a tutor without the
  /// `canEditStudyDays` permission cannot change the day type.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isStudy
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isStudy ? Icons.menu_book : Icons.refresh,
                  color: isStudy
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dayLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Flexible + ellipsis so the badge shrinks rather than
                // overflowing the row at large text on narrow screens.
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isStudy
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isStudy
                          ? AppLocalizations.of(context)!.schedulerStudyLabel
                          : AppLocalizations.of(
                              context,
                            )!.schedulerReviewOnlyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isStudy
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline warning banner shown when zero study days are selected for the week
/// (everything review-only). Uses the theme error colours so it reads as a
/// caution without blocking the user, mirroring the app's inline-warning idiom.
class _ZeroStudyDaysWarning extends StatelessWidget {
  const _ZeroStudyDaysWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // Flexible + ellipsis so a long label at large text ellipsizes
        // instead of overflowing the (Wrap-bounded) legend chip.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
