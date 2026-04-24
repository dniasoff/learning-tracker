import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow.dart';

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
  bool _showArchived = true;
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
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(
          'Manage Tracks',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandBlueDeep,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              icon: Icon(
                _showArchived ? Icons.visibility_off_rounded : Icons.visibility,
                size: 18,
              ),
              label: Text(_showArchived ? 'Hide Archived' : 'Show Archived'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDEE4FF),
                foregroundColor: AppTheme.brandBlueDeep,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (activeAsync.asData?.value.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _addingTrack = true),
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              label: const Text('ADD TRACK'),
              backgroundColor: AppTheme.brandBlue,
              foregroundColor: Colors.white,
              extendedPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              top: 8,
              bottom: 96,
            ),
            children: [
              if (activeTracks.isNotEmpty) ...[
                _buildActiveHeader(
                  context,
                  activeTracks.length,
                ),
                ...activeTracks.map(
                  (track) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TrackCard(
                      track: track,
                      showProgress: true,
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
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                        child: Text(
                          'No archived tracks',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.brandInkMuted,
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildArchivedHeader(context),
                        ...archivedTracks.map(
                          (track) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TrackCard(
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

  Widget _buildActiveHeader(
    BuildContext context,
    int activeCount,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Active Tracks',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.brandInk,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2CF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$activeCount RUNNING',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFE9A42A),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFDDE3EE))),
          const SizedBox(width: 12),
          Text(
            'Archived',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.brandInkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFFDDE3EE))),
        ],
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

class _TrackCard extends ConsumerWidget {
  const _TrackCard({
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
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;
    final hebrewName = curriculum?.displayNameHe ?? track.curriculumId;
    final englishName = curriculum?.displayNameEn ?? track.curriculumId;
    final completion = curriculum == null
        ? const AsyncData<double>(0.0)
        : ref.watch(dashboardCompletionPercentageProvider(curriculum));
    final progress = completion.asData?.value ?? 0.0;

    final accent = _trackAccentColor(track.trackType);
    final icon = _trackTypeIcon(track.trackType);
    final trackLabel = _trackLabel(track.trackType);

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

IconData _trackTypeIcon(String trackType) {
  return switch (trackType) {
    'personal' => Icons.menu_book_rounded,
    'school' => Icons.auto_awesome_rounded,
    'advanced' => Icons.verified_rounded,
    _ => Icons.menu_book_rounded,
  };
}

String _trackLabel(String trackType) {
  return switch (trackType) {
    'personal' => 'Personal Track',
    'school' => 'School Track',
    'advanced' => 'Advanced Track',
    _ => 'Learning Track',
  };
}

Color _trackAccentColor(String trackType) {
  return switch (trackType) {
    'personal' => const Color(0xFF1C47C4),
    'school' => const Color(0xFFBC8105),
    'advanced' => const Color(0xFF0EAE81),
    _ => AppTheme.brandBlue,
  };
}
