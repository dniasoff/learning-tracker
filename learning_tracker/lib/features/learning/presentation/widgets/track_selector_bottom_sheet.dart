import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Bottom sheet for selecting which track to assign a completion to.
///
/// Displays a list of active tracks for the user to choose from when
/// marking a content item as complete.
class TrackSelectorBottomSheet extends StatelessWidget {
  /// List of active tracks to display
  final List<TrackType> activeTracks;

  /// Callback when a track is selected
  final ValueChanged<TrackType> onTrackSelected;

  const TrackSelectorBottomSheet({
    super.key,
    required this.activeTracks,
    required this.onTrackSelected,
  });

  /// Shows the track selector bottom sheet.
  ///
  /// Returns the selected [TrackType] or null if dismissed.
  static Future<TrackType?> show({
    required BuildContext context,
    required List<TrackType> activeTracks,
  }) {
    return showModalBottomSheet<TrackType>(
      context: context,
      builder: (context) => TrackSelectorBottomSheet(
        activeTracks: activeTracks,
        onTrackSelected: (track) => Navigator.of(context).pop(track),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select Track', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Choose which track to assign this completion to:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...activeTracks.map(
              (track) =>
                  _TrackTile(track: track, onTap: () => onTrackSelected(track)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final TrackType track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(_getTrackIcon(track)),
              const SizedBox(width: 16),
              Text(
                track.displayNameEn,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTrackIcon(TrackType track) {
    return switch (track) {
      TrackType.personal => Icons.person,
      TrackType.school => Icons.school,
      TrackType.tutor => Icons.groups,
    };
  }
}
