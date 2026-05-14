import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Day labels in display order: Sunday first (ISO weekday 7), then Mon(1)..Sat(6).
const _displayOrder = [7, 1, 2, 3, 4, 5, 6];
const _dayLabels = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

@RoutePage()
class StudyDayConfigScreen extends ConsumerWidget {
  final CurriculumId curriculumId;

  const StudyDayConfigScreen({super.key, required this.curriculumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(studyDayConfigsProvider(curriculumId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text:
              '${curriculumLabelText(ref, curriculum: curriculumId)} Study Days',
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

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose which days include new learning and which are for review (chazara) only.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _LegendDot(
                        color: theme.colorScheme.primary,
                        label: AppLocalizations.of(
                          context,
                        )!.schedulerStudyLabel,
                      ),
                      const SizedBox(width: 16),
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
                      dayLabel: _dayLabels[dow]!,
                      isStudy: isStudy,
                      onToggle: () => _toggleDay(
                        ref,
                        dow,
                        isStudy ? DayType.review : DayType.study,
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  // Summary
                  Builder(
                    builder: (context) {
                      final studyCount = _displayOrder
                          .where(
                            (dow) =>
                                (dayTypeMap[dow] ?? DayType.study) ==
                                DayType.study,
                          )
                          .length;
                      return Center(
                        child: Text(
                          '$studyCount study day${studyCount == 1 ? '' : 's'} per week',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              AppLocalizations.of(context)!.errorGeneric(e.toString()),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDay(WidgetRef ref, int dayOfWeek, DayType newType) {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    // Look up trackId then upsert
    (db.select(db.curriculumTracks)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals(curriculumId.storageKey),
          )
          ..limit(1))
        .getSingleOrNull()
        .then((track) {
          final trackId = track?.id ?? 0;
          db.studyDayConfigDao.upsertDayConfig(
            profileId: profileId,
            curriculumId: curriculumId.storageKey,
            trackId: trackId,
            dayOfWeek: dayOfWeek,
            dayType: newType.storageKey,
          );
        });
    ref.invalidate(allDailyTasksProvider);
  }
}

class _DayToggleTile extends StatelessWidget {
  const _DayToggleTile({
    required this.dayLabel,
    required this.isStudy,
    required this.onToggle,
  });

  final String dayLabel;
  final bool isStudy;
  final VoidCallback onToggle;

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
                Container(
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
                    isStudy ? 'Study' : 'Review',
                    style: TextStyle(
                      color: isStudy
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
