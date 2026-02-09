import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';

/// A chip widget for selecting the active track when marking completions.
///
/// Displays all active tracks for a curriculum and allows the user to
/// select which track they're working on. Only active tracks are shown.
///
/// When only personal track is active, it can auto-select without user input.
/// When multiple tracks are active, shows a selector UI.
class TrackSelectorChip extends ConsumerWidget {
  const TrackSelectorChip({
    super.key,
    required this.curriculumId,
    required this.selectedTrack,
    required this.onTrackSelected,
  });

  final CurriculumId curriculumId;
  final TrackType? selectedTrack;
  final ValueChanged<TrackType> onTrackSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTracksAsync = ref.watch(activeTracksProvider(curriculumId));

    return activeTracksAsync.when(
      data: (activeTracks) {
        if (activeTracks.isEmpty) {
          return const SizedBox.shrink();
        }

        if (activeTracks.length == 1) {
          // Only one track active - show it as selected but not interactive
          final track = activeTracks.first;
          return Chip(
            avatar: const Icon(Icons.check, size: 16),
            label: Text(track.displayNameEn),
          );
        }

        // Multiple tracks active - show selector
        return Wrap(
          spacing: 8,
          children: activeTracks.map((track) {
            final isSelected = selectedTrack == track;
            return ChoiceChip(
              label: Text(track.displayNameEn),
              selected: isSelected,
              onSelected: (_) => onTrackSelected(track),
            );
          }).toList(),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

/// Provider for managing the currently selected track.
///
/// This is a simple state provider that can be used to track which track
/// is currently selected in the completion flow.
final selectedTrackProvider = StateProvider.family<TrackType?, CurriculumId>(
  (ref, curriculumId) => null,
);
