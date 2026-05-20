import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shared body widget for both parent and child track-management screens.
///
/// Both screens are structurally identical. The only role-specific difference
/// is whether the [AppBar] renders a back button — pass [showBackButton] = true
/// for the parent-mode screen (which is pushed onto the nav stack) and false for
/// the child-mode hub screen (which is a root tab destination).
class TrackManagementBody extends ConsumerStatefulWidget {
  const TrackManagementBody({super.key, this.showBackButton = false});

  /// Whether to render a leading back-navigation button in the [AppBar].
  ///
  /// Set to `true` for parent-mode (pushed route); leave `false` for the
  /// child-mode hub (tab root, no stack pop needed).
  final bool showBackButton;

  @override
  ConsumerState<TrackManagementBody> createState() =>
      _TrackManagementBodyState();
}

class _TrackManagementBodyState extends ConsumerState<TrackManagementBody> {
  bool _addingTrack = false;

  @override
  Widget build(BuildContext context) {
    if (_addingTrack) {
      return Scaffold(
        body: AddTrackFlow(
          profileId: ref.watch(activeProfileIdProvider),
          isOnboarding: false,
          onComplete: _onAddTrackComplete,
          onCancel: () => setState(() => _addingTrack = false),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final activeAsync = ref.watch(activeTracksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppTheme.brandBlueDeep,
                onPressed: () => context.maybePop(),
              )
            : null,
        title: Text(
          l10n.manageTracks,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandBlueDeep,
          ),
        ),
      ),
      floatingActionButton: activeAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (activeTracks) =>
            activeTracks.isNotEmpty ? _buildAddTrackFab() : null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (activeTracks) {
          if (activeTracks.isEmpty) {
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
              _buildActiveHeader(context, activeTracks.length),
              ...activeTracks.map(
                (track) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LearningTrackCard(
                    track: track,
                    showProgress: true,
                    onTap: () =>
                        context.router.push(TrackDetailRoute(track: track)),
                    onLongPress: () => _showDeleteDialog(track),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddTrackFab() {
    return FloatingActionButton.extended(
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
      label: Text(AppLocalizations.of(context)!.trackAddLabel),
      backgroundColor: AppTheme.brandBlue,
      foregroundColor: Colors.white,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildActiveHeader(BuildContext context, int activeCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.activeTracksLabel,
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
              AppLocalizations.of(context)!.activeTracksRunning(activeCount),
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
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.trackCreated(result.label))));
  }

  Future<void> _showDeleteDialog(CurriculumTrack track) async {
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;

    final l10n = AppLocalizations.of(context)!;

    // 'archive' = keep history; 'wipe' = hard-delete completions; null = cancel
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTrackArchiveTitle),
        content: Text(l10n.deleteTrackArchiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'archive'),
            child: Text(l10n.deleteTrackArchive),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, 'wipe'),
            child: Text(l10n.deleteTrackWipe),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (curriculum != null && choice == 'archive') {
      try {
        await ref
            .read(curriculumActivationServiceProvider)
            .deactivate(curriculum);
        await onTrackChanged(ref, track.profileId);
      } on LastActiveCurriculumException {
        if (!mounted) return;
        _showLastCurriculumError(l10n);
      }
    } else {
      final dao = ref.read(userDatabaseProvider).trackDao;
      if (choice == 'wipe') {
        await dao.purgeHistory(track.id);
      } else {
        await dao.deleteTrackAndData(track.id);
      }
      await onTrackChanged(ref, track.profileId);
    }
  }

  void _showLastCurriculumError(AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cannotDeactivateLastCurriculum,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.cannotDeactivateLastCurriculumDetail,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
