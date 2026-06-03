import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
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
    // Resolve the curriculum's active track to gate the chazara/review UI.
    // Per the per-track chazara rule, a learn-only track must not show any
    // chazara/review references — body copy, legend, or the review-day toggle.
    final trackChazaraAsync = ref.watch(
      _curriculumTrackHasChazaraProvider(curriculumId),
    );
    final trackHasChazara = trackChazaraAsync.asData?.value ?? false;

    // WS3.3d carry-forward: when a tutor has entered a talmid's context, gate
    // study-day editing behind `canEditStudyDays`. Owners (non-tutored context)
    // always edit. Mirrors the gating in parent_settings_screen.
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final canEdit = tutorPerms == null || tutorPerms.canEditStudyDays;

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
                    'All days are study days for this track.',
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
                    'Choose which days include new learning and which are for review only.',
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
                      dayLabel: _dayLabels[dow]!,
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
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final syncFacade = ref.read(syncWriteFacadeProvider);
    // Look up trackId then upsert
    (db.select(db.curriculumTracks)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals(curriculumId.storageKey),
          )
          ..limit(1))
        .getSingleOrNull()
        .then((track) async {
          final trackId = track?.id ?? 0;
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: profileId,
            curriculumId: curriculumId.storageKey,
            trackId: trackId,
            dayOfWeek: dayOfWeek,
            dayType: newType.storageKey,
          );
          try {
            await syncFacade?.pushStudyDayConfig({
              'profile_id': profileId,
              'curriculum_id': curriculumId.storageKey,
              'track_id': trackId,
              'day_of_week': dayOfWeek,
              'day_type': newType.storageKey,
              'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
            });
          } on TutorWriteException catch (e) {
            if (context.mounted && e.code == 'permission-denied') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.tutorPermissionDenied,
                  ),
                ),
              );
            }
          }
        });
    ref.invalidate(allDailyTasksProvider);
  }
}

/// True when the active-profile curriculum track for [curriculumId] has
/// more than one stage (i.e. chazara is enabled). Keyed by curriculum
/// rather than trackId because this screen receives only a curriculumId.
final _curriculumTrackHasChazaraProvider = FutureProvider.autoDispose
    .family<bool, CurriculumId>((ref, curriculumId) async {
      final db = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      final track =
          await (db.select(db.curriculumTracks)
                ..where(
                  (t) =>
                      t.profileId.equals(profileId) &
                      t.curriculumId.equals(curriculumId.storageKey),
                )
                ..limit(1))
              .getSingleOrNull();
      if (track == null) return false;
      final count = await db.stageDao.countStagesForTrack(track.id);
      return count > 1;
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
