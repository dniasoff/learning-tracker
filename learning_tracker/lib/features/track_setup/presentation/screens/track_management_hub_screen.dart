import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/track_list_tile.dart';

/// Central hub for viewing, adding, editing, and archiving tracks.
///
/// Replaces the old per-curriculum TrackManagementScreen.
@RoutePage()
class TrackManagementHubScreen extends ConsumerStatefulWidget {
  const TrackManagementHubScreen({
    super.key,
    @QueryParam('startAdding') this.startAdding = false,
  });

  final bool startAdding;

  @override
  ConsumerState<TrackManagementHubScreen> createState() =>
      _TrackManagementHubScreenState();
}

class _TrackManagementHubScreenState
    extends ConsumerState<TrackManagementHubScreen> {
  bool _showArchived = false;
  late bool _addingTrack = widget.startAdding;

  @override
  Widget build(BuildContext context) {
    if (_addingTrack) {
      return Scaffold(
        body: AddTrackFlow(
          profileId: ref.watch(activeProfileIdProvider),
          isOnboarding: false,
          isChildMode:
              ref.watch(dashboardUserModeProvider).value == UserMode.child,
          onComplete: _onAddTrackComplete,
          onCancel: () => setState(() => _addingTrack = false),
        ),
      );
    }

    final activeAsync = ref.watch(activeTracksProvider);
    final archivedAsync = ref.watch(archivedTracksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tracks'),
        actions: [
          FilterChip(
            label: Text(_showArchived ? 'Hide Archived' : 'Show Archived'),
            selected: _showArchived,
            onSelected: (v) => setState(() => _showArchived = v),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: (activeAsync.asData?.value.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _addingTrack = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Track'),
            )
          : null,
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (activeTracks) {
          if (activeTracks.isEmpty && !_showArchived) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80,
            ),
            children: [
              if (activeTracks.isNotEmpty) ...[
                _buildSectionHeader(context, 'Active Tracks'),
                ...activeTracks.map(
                  (track) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TrackListTile(
                      track: track,
                      onTap: () => _onTrackTap(track),
                      onLongPress: () => _showArchiveDialog(track),
                    ),
                  ),
                ),
              ],
              if (_showArchived)
                archivedAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Error loading archived: $e'),
                  data: (archivedTracks) {
                    if (archivedTracks.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No archived tracks'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildSectionHeader(context, 'Archived'),
                        ...archivedTracks.map(
                          (track) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TrackListTile(
                              track: track,
                              isArchived: true,
                              onTap: () => _showReactivateDialog(track),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('No tracks yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add your first learning track to get started.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _addingTrack = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Track'),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddTrackComplete(AddTrackResult result) {
    setState(() => _addingTrack = false);
    ref.invalidate(activeTracksProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Track "${result.label}" created')));
  }

  void _onTrackTap(CurriculumTrack track) {
    context.router.push(
      TrackDetailRoute(
        curriculumId: track.curriculumId,
        trackType: track.trackType,
      ),
    );
  }

  Future<void> _showArchiveDialog(CurriculumTrack track) async {
    // Prevent archiving the last active track
    final activeCount = await ref
        .read(userDatabaseProvider)
        .trackDao
        .countActiveTracksForProfile(track.profileId);
    if (activeCount <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot archive your only active track')),
      );
      return;
    }

    if (!mounted) return;
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;
    final name = curriculum?.displayNameHe ?? track.curriculumId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Track?'),
        content: Text(
          'Archive "$name"? Your data and progress will be preserved. '
          'You can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      final db = ref.read(userDatabaseProvider);
      await db.trackDao.archiveTrack(
        track.profileId,
        curriculum ?? CurriculumId.mishnayos,
        TrackType.values
                .where((t) => t.storageKey == track.trackType)
                .firstOrNull ??
            TrackType.personal,
      );
      ref.invalidate(activeTracksProvider);
      ref.invalidate(archivedTracksProvider);
    }
  }

  Future<void> _showReactivateDialog(CurriculumTrack track) async {
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;
    final name = curriculum?.displayNameHe ?? track.curriculumId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate Track?'),
        content: Text(
          'Reactivate "$name"? It will appear on your dashboard again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      final db = ref.read(userDatabaseProvider);
      await db.trackDao.unarchiveTrack(
        track.profileId,
        curriculum ?? CurriculumId.mishnayos,
        TrackType.values
                .where((t) => t.storageKey == track.trackType)
                .firstOrNull ??
            TrackType.personal,
      );
      ref.invalidate(activeTracksProvider);
      ref.invalidate(archivedTracksProvider);
    }
  }
}
