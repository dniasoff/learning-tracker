/// Today against the daily target, with warm encouragement and the
/// curriculum streak (Story 2.11, DNI-502; screen #01, UX-DR-67,
/// UX-DR-96).
///
/// The figures are the engine's ([learnerTodayProvider]): today's new
/// leaves, `dailyTarget` and the curriculum streak. Every role may see
/// them; nothing here is a status, a projection or a shortfall, and the
/// copy never says behind, off track or failing (NFR-9, UX-DR-97). A zero
/// target is valid, not an error: it shows the bonus copy (FR-19).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// One [LearnerTodayCard] per evaluated curriculum, followed by
/// [bottomSpacing]. It takes no space while loading or with nothing to
/// show; a load error is an [InlineAsyncError] with retry.
class LearnerTodaySection extends ConsumerWidget {
  /// Creates the section.
  const LearnerTodaySection({super.key, this.bottomSpacing = 24});

  /// Space after the section when it shows anything.
  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(learnerTodayProvider);
    if (today case AsyncError(:final error)) {
      return Padding(
        padding: EdgeInsetsDirectional.only(bottom: bottomSpacing),
        child: InlineAsyncError(
          error: error,
          onRetry: () => retryLearnerForecast(ref),
        ),
      );
    }
    final list = today.value ?? const <CurriculumToday>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, figures) in list.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            LearnerTodayCard(today: figures, showCurriculum: list.length > 1),
          ],
        ],
      ),
    );
  }
}

/// Today's progress for one curriculum.
class LearnerTodayCard extends StatelessWidget {
  /// Creates the card.
  const LearnerTodayCard({
    super.key,
    required this.today,
    this.showCurriculum = false,
  });

  /// The engine figures.
  final CurriculumToday today;

  /// Whether to name the curriculum (more than one is shown).
  final bool showCurriculum;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final target = today.target;
    final done = today.done;

    final String headline;
    String? encouragement;
    if (target == 0) {
      headline = l10n.todayTargetAllCovered;
    } else if (target == null) {
      headline = l10n.todayTargetLearntToday(
        formatForecastCount(context, done),
      );
    } else {
      headline = l10n.todayTargetProgress(
        formatForecastCount(context, done),
        formatForecastCount(context, target),
      );
      encouragement = done == 0
          ? l10n.todayTargetStart
          : done >= target
          ? l10n.todayTargetGoalDone
          : l10n.todayTargetLeft(target - done);
    }
    final streak = today.streak?.current ?? 0;

    return ForecastCardFrame(
      key: Key('learnerTodayCard-${today.curriculumId}'),
      color: colors.brandCreamCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCurriculum && today.curriculum != null) ...[
            CurriculumLabel.curriculum(
              today.curriculum!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.brandInkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            headline,
            key: const Key('learnerTodayHeadline'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.brandInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (encouragement != null) ...[
            const SizedBox(height: 4),
            Text(
              encouragement,
              key: const Key('learnerTodayEncouragement'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInkMuted,
              ),
            ),
          ],
          if (streak > 0) ...[
            const SizedBox(height: 10),
            Row(
              key: const Key('learnerTodayStreak'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: colors.statusDanger,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.todayTargetStreak(streak),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.brandInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
