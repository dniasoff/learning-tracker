import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

/// Rich track row used on [TrackManagementHubScreen] and
/// [ParentTrackManagementScreen] (same visual design).
///
/// Progress bar uses [TrackDualProgressMetric.lifetimePercentage] (ledger +
/// completions within the track scope), same metric as the dashboard track
/// rows — not the stage-cycle-only completion percentage.
class LearningTrackCard extends ConsumerWidget {
  const LearningTrackCard({
    super.key,
    required this.track,
    this.isArchived = false,
    this.showProgress = false,
    this.onTap,
    this.onLongPress,
  });

  final CurriculumTrack track;
  final bool isArchived;
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
    final hebrewName = curriculum?.displayNameHe ?? track.curriculumId;
    final englishName = curriculum?.displayNameEn ?? track.curriculumId;

    final profileId = ref.watch(activeProfileIdProvider);
    final metricsAsync = ref.watch(trackDualProgressMetricsProvider(profileId));
    final progress = metricsAsync.when(
      data: (metrics) {
        for (final m in metrics) {
          if (m.trackId == track.id) return m.lifetimePercentage;
        }
        return 0.0;
      },
      loading: () => 0.0,
      error: (_, __) => 0.0,
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
          padding: EdgeInsets.symmetric(
            horizontal: isArchived ? 14 : 16,
            vertical: isArchived ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: isArchived ? const Color(0xFFF2F5FB) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: isArchived
                ? Border.all(color: const Color(0xFFD7DFEC))
                : null,
            boxShadow: isArchived
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0A2056).withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: isArchived ? 0.82 : 1,
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isArchived
                        ? null
                        : [
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
                      Text(
                        '$hebrewName \u2022 $englishName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.brandBlueDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trackLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isArchived)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'ARCHIVED',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.brandInkMuted,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ),
                        ),
                      if (showProgress && !isArchived) ...[
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
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
                if (!isArchived)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 30,
                    color: AppTheme.brandBlueDeep,
                  ),
              ],
            ),
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
