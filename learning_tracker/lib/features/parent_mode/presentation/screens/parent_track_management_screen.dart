import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/parent_mode/presentation/providers/parent_track_providers.dart';

/// Parent mode screen for managing tracks across all curricula.
///
/// Shows each active curriculum with its current tracks, allowing the parent
/// to add school/tutor tracks or remove them (with confirmation).
/// Personal track is always shown but cannot be removed.
@RoutePage()
class ParentTrackManagementScreen extends ConsumerWidget {
  const ParentTrackManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(parentTrackCurriculaProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Manage Tracks')),
      body: SafeArea(
        top: false,
        child: activeCurriculaAsync.when(
          data: (curricula) => curricula.isEmpty
              ? const Center(child: Text('No active curricula'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: curricula.length,
                  itemBuilder: (context, index) =>
                      _CurriculumTrackCard(curriculum: curricula[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error loading curricula: $error')),
        ),
      ),
    );
  }
}

class _CurriculumTrackCard extends ConsumerWidget {
  final CurriculumId curriculum;

  const _CurriculumTrackCard({required this.curriculum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTracksAsync = ref.watch(activeTracksProvider(curriculum));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              curriculum.displayNameHe,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            activeTracksAsync.when(
              data: (activeTracks) => Column(
                children: [
                  _TrackRow(
                    curriculum: curriculum,
                    trackType: TrackType.personal,
                    isActive: activeTracks.contains(TrackType.personal),
                    isPersonal: true,
                  ),
                  _TrackRow(
                    curriculum: curriculum,
                    trackType: TrackType.school,
                    isActive: activeTracks.contains(TrackType.school),
                  ),
                  _TrackRow(
                    curriculum: curriculum,
                    trackType: TrackType.tutor,
                    isActive: activeTracks.contains(TrackType.tutor),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends ConsumerWidget {
  final CurriculumId curriculum;
  final TrackType trackType;
  final bool isActive;
  final bool isPersonal;

  const _TrackRow({
    required this.curriculum,
    required this.trackType,
    required this.isActive,
    this.isPersonal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(trackType.displayNameEn),
      subtitle: isPersonal
          ? const Text('Always active')
          : Text(isActive ? 'Active' : 'Inactive'),
      value: isActive,
      onChanged: isPersonal
          ? null
          : (value) async {
              if (value) {
                await _activateTrack(context, ref);
              } else {
                await _deactivateTrack(context, ref);
              }
            },
    );
  }

  Future<void> _activateTrack(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(trackRepositoryProvider);
      await repository.activateTrack(curriculum, trackType);
      ref.invalidate(activeTracksProvider(curriculum));
    } on Exception catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to activate track: $e')));
    }
  }

  Future<void> _deactivateTrack(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Track?'),
        content: Text(
          'Removing the ${trackType.displayNameEn} track will hide it from '
          'the learning view. Completion history will be preserved. '
          'You can add it back later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      if (!context.mounted) return;
      try {
        final repository = ref.read(trackRepositoryProvider);
        await repository.deactivateTrack(curriculum, trackType);
        ref.invalidate(activeTracksProvider(curriculum));
      } on Exception catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove track: $e')));
      }
    }
  }
}
