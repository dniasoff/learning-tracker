import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Displays total points with curriculum breakdown.
///
/// In [ProfileMode.child] mode, points are displayed prominently.
/// In [ProfileMode.adult] mode, points are hidden.
class PointsDisplayWidget extends ConsumerWidget {
  final ProfileMode userMode;

  const PointsDisplayWidget({super.key, required this.userMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userMode.isAdult) {
      return const SizedBox.shrink();
    }

    final globalPoints = ref.watch(globalPointsProvider);
    final breakdown = ref.watch(curriculumBreakdownProvider);
    final l10n = AppLocalizations.of(context)!;

    return globalPoints.when(
      data: (total) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$total',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            AppLocalizations.of(context)!.totalPointsLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          breakdown.when(
            data: (map) => Wrap(
              spacing: 12,
              children: map.entries
                  .map(
                    (e) => Chip(
                      label: Text(
                        l10n.commonLabelWithValue(
                          curriculumLabelText(ref, curriculum: e.key),
                          '${e.value}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => Text(AppLocalizations.of(context)!.errorLoadingPoints),
    );
  }
}
