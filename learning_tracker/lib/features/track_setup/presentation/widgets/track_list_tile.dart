import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';

/// A list tile displaying a single track's summary info.
class TrackListTile extends ConsumerWidget {
  const TrackListTile({
    required this.track,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final CurriculumTrack track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  CurriculumId? get _curriculumId {
    return CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculum = _curriculumId;
    final useHebrew = ref.watch(useHebrewTermsProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (curriculum != null)
                      CurriculumLabel.curriculum(
                        curriculum,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        track.curriculumId,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (curriculum != null && !useHebrew) ...[
                      const SizedBox(height: 2),
                      Text(
                        curriculumHebrewName(curriculum),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    Text(
                      track.trackType,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
