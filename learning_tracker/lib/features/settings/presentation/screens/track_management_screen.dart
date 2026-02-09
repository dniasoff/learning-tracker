import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';

/// Screen for managing track activation per curriculum.
///
/// Allows users to:
/// - View which tracks are active for a curriculum
/// - Add school and/or tutor tracks (toggle on)
/// - Remove school and/or tutor tracks (toggle off)
/// - See that personal track is always on (cannot be toggled)
///
/// Removing a track preserves completion data but hides the track from UI.
@RoutePage()
class TrackManagementScreen extends ConsumerWidget {
  const TrackManagementScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => CurriculumId.mishnayos,
    );

    final activeTracksAsync = ref.watch(activeTracksProvider(curriculum));

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Tracks - ${curriculum.displayNameEn}'),
      ),
      body: activeTracksAsync.when(
        data: (activeTracks) => _buildTrackList(
          context,
          ref,
          curriculum,
          activeTracks,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading tracks: $error'),
        ),
      ),
    );
  }

  Widget _buildTrackList(
    BuildContext context,
    WidgetRef ref,
    CurriculumId curriculum,
    List<TrackType> activeTracks,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTrackTile(
          context,
          ref,
          curriculum,
          TrackType.personal,
          activeTracks.contains(TrackType.personal),
          isPersonal: true,
        ),
        _buildTrackTile(
          context,
          ref,
          curriculum,
          TrackType.school,
          activeTracks.contains(TrackType.school),
        ),
        _buildTrackTile(
          context,
          ref,
          curriculum,
          TrackType.tutor,
          activeTracks.contains(TrackType.tutor),
        ),
      ],
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    WidgetRef ref,
    CurriculumId curriculum,
    TrackType trackType,
    bool isActive, {
    bool isPersonal = false,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(trackType.displayNameEn),
        subtitle: isPersonal
            ? const Text('Always active')
            : Text(isActive ? 'Active' : 'Inactive'),
        value: isActive,
        onChanged: isPersonal
            ? null // Personal track cannot be toggled
            : (value) async {
                if (value) {
                  await _activateTrack(ref, curriculum, trackType);
                } else {
                  await _deactivateTrack(
                    context,
                    ref,
                    curriculum,
                    trackType,
                  );
                }
              },
      ),
    );
  }

  Future<void> _activateTrack(
    WidgetRef ref,
    CurriculumId curriculum,
    TrackType trackType,
  ) async {
    final repository = ref.read(trackRepositoryProvider);
    await repository.activateTrack(curriculum, trackType);
    // Invalidate provider to trigger refresh
    ref.invalidate(activeTracksProvider(curriculum));
  }

  Future<void> _deactivateTrack(
    BuildContext context,
    WidgetRef ref,
    CurriculumId curriculum,
    TrackType trackType,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Track?'),
        content: Text(
          'Deactivating ${trackType.displayNameEn} track will hide it from the UI, '
          'but your completion history will be preserved. You can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(trackRepositoryProvider);
      await repository.deactivateTrack(curriculum, trackType);
      // Invalidate provider to trigger refresh
      ref.invalidate(activeTracksProvider(curriculum));
    }
  }
}
