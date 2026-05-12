import 'package:flutter/material.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// A list tile displaying a single track's summary info.
class TrackListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curriculum = _curriculumId;
    final hebrewName = curriculum?.displayNameHe ?? track.curriculumId;
    final englishName = curriculum?.displayNameEn ?? track.curriculumId;

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
                    Text(
                      hebrewName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      englishName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
