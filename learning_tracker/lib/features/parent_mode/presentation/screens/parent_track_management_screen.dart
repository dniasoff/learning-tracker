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
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart'
    as tm;
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Parent mode: same track UI as [TrackManagementHubScreen], scoped to the
/// active (child) profile via [activeProfileIdProvider] and [tm.activeTracksProvider].
@RoutePage()
class ParentTrackManagementScreen extends ConsumerStatefulWidget {
  const ParentTrackManagementScreen({super.key});

  @override
  ConsumerState<ParentTrackManagementScreen> createState() =>
      _ParentTrackManagementScreenState();
}

class _ParentTrackManagementScreenState
    extends ConsumerState<ParentTrackManagementScreen> {
  bool _showArchived = true;
  bool _addingTrack = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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

    final activeAsync = ref.watch(tm.activeTracksProvider);
    final archivedAsync = ref.watch(tm.archivedTracksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppTheme.brandBlueDeep,
          onPressed: () => context.maybePop(),
        ),
        title: Text(
          l10n.manageTracks,
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
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (activeTracks) {
          if (activeTracks.isEmpty && !_showArchived) {
            return _buildEmptyState(l10n);
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
                _buildActiveHeader(context, activeTracks.length),
                ...activeTracks.map(
                  (track) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LearningTrackCard(
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
                            child: LearningTrackCard(
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

  Widget _buildActiveHeader(BuildContext context, int activeCount) {
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

  Widget _buildEmptyState(AppLocalizations l10n) {
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
            Text(l10n.noActiveTracks, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              l10n.manageTracksDetail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _addingTrack = true),
              icon: const Icon(Icons.add),
              label: Text(l10n.addTrack),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddTrackComplete(AddTrackResult result) {
    setState(() => _addingTrack = false);
    ref.invalidate(tm.activeTracksProvider);
    ref.invalidate(tm.archivedTracksProvider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.trackCreated(result.label))),
    );
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
    final activeCount = await ref
        .read(userDatabaseProvider)
        .trackDao
        .countActiveTracksForProfile(track.profileId);
    if (activeCount <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot archive your only active track'),
        ),
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
      ref.invalidate(tm.activeTracksProvider);
      ref.invalidate(tm.archivedTracksProvider);
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
      ref.invalidate(tm.activeTracksProvider);
      ref.invalidate(tm.archivedTracksProvider);
    }
  }
}
