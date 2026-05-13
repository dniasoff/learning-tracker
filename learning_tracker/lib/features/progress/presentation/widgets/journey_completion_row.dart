import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/track_type_badge.dart';

/// Shared single-completion row used by both [JourneyTimelineView] and
/// [JourneyGroupedView].
///
/// Renders the display label via [CurriculumLabel.level] so label resolution
/// is locale-aware and transliteration-variant-aware — no display strings are
/// stored on [UnitCompletion] itself.
class JourneyCompletionRow extends ConsumerWidget {
  const JourneyCompletionRow({
    super.key,
    required this.completion,
    required this.curriculumId,
    required this.curriculumColor,
    this.subtitle,
    this.dense = false,
  });

  final UnitCompletion completion;
  final CurriculumId curriculumId;
  final Color curriculumColor;

  /// Optional extra subtitle text shown below the label. When `null` the
  /// [TrackTypeBadge] is placed in the trailing slot instead.
  final String? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = unitCompletionLevel(completion.entryScope);
    final labelWidget = CurriculumLabel.level(
      curriculumId: curriculumId,
      level: level,
      rawValue: completion.entryKey,
      parentL1Value: completion.parentL1Key,
    );

    final leading = Container(
      width: dense ? 4 : 8,
      height: dense ? 32 : 40,
      decoration: BoxDecoration(
        color: curriculumColor,
        borderRadius: BorderRadius.circular(dense ? 2 : 4),
      ),
    );

    if (dense) {
      // Compact tile layout used by the grouped view.
      return ListTile(
        dense: true,
        leading: leading,
        title: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                child: labelWidget,
              ),
            ),
            TrackTypeBadge(trackType: completion.trackType),
          ],
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
      );
    }

    // Card layout used by the timeline view.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: leading,
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          child: labelWidget,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: TrackTypeBadge(trackType: completion.trackType),
      ),
    );
  }
}
