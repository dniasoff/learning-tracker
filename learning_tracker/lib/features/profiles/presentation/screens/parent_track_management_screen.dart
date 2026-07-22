import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    as tm;
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
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
  bool _addingTrack = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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

    final activeAsync = ref.watch(tm.activeTracksProvider);

    // asData?.value.isNotEmpty: the `?.` on asData short-circuits the entire
    // value.isNotEmpty chain when asData is null (loading/error), so `?? false`
    // correctly falls back.  No NPE is possible here (AsyncData.value is T,
    // non-nullable).
    final showAddTrackFab = activeAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: context.colors.brandBlueDeep,
          onPressed: () => context.maybePop(),
        ),
        title: Text(
          // Reached from both "Manage Tracks" and "Manage Goals" (goals are
          // set per-track from each card here), so the title covers both —
          // arriving from Manage Goals no longer reads as the wrong screen.
          l10n.manageTracksAndGoalsTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandBlueDeep,
          ),
        ),
      ),
      floatingActionButton: showAddTrackFab
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
              label: Text(l10n.addTrackButton),
              backgroundColor: context.colors.brandBlue,
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
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () => ref.refresh(tm.activeTracksProvider),
        ),
        data: (activeTracks) {
          if (activeTracks.isEmpty) {
            return _buildEmptyState(l10n);
          }

          return ListView(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
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

  Widget _buildActiveHeader(BuildContext context, int activeCount) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.activeTracksLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colors.brandInk,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.colors.warnYellow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.activeTracksRunning(activeCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.goldAmber,
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
            // TS-14: use child-scoped copy in this parent-manages-child context.
            Text(
              l10n.parentManageTracksDetail,
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
    final l10n = AppLocalizations.of(context)!;

    // R-TR2 / TS-16: Pre-check whether Archive/Delete is allowed before
    // showing the dialog. When this track is the only active curriculum for
    // the child profile, surfacing the destructive actions would leave the
    // profile with zero active curricula (dashboard dead-end).
    final activeCurricula = await ref
        .read(userDatabaseProvider)
        .activeCurriculumDao
        .getActiveCurriculaByProfile(track.profileId);
    if (!mounted) return;

    final canDelete = activeCurricula.length > 1;

    // 'archive' = keep history; 'wipe' = hard-delete completions; null = cancel
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTrackArchiveTitle),
        // TS-14: use child-scoped body copy ("your child's completion history").
        // TS-16: when it's the last curriculum show blocking explanation instead.
        content: Text(
          canDelete
              ? l10n.parentDeleteTrackArchiveBody
              : l10n.cannotDeactivateLastCurriculum,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          if (canDelete) ...[
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
        ],
      ),
    );

    if (choice == null || !mounted) return;

    // Defensive guard (canDelete was true since the dialog showed the actions).
    if (!canDelete) {
      _showLastCurriculumError(l10n);
      return;
    }

    if (choice == 'archive') {
      final curriculum = CurriculumId.values
          .where((c) => c.storageKey == track.curriculumId)
          .firstOrNull;
      if (curriculum != null) {
        try {
          // AUD-profiles-01: route through the archive path — not
          // deactivate(), which hard-deletes goals/stages/point config via
          // deleteTrackAndData and would make "Archive (keep history)"
          // behave exactly like "Delete and wipe history". archive() still
          // enforces the last-curriculum invariant (throws
          // LastActiveCurriculumException).
          await ref
              .read(curriculumActivationServiceProvider)
              .archive(curriculum);
          await invalidateAfterTrackDataChange(ref, track.profileId);
        } on LastActiveCurriculumException {
          if (!mounted) return;
          _showLastCurriculumError(l10n);
        }
        return;
      }
    }

    // Wipe path: hard-delete the track and its history.
    final dao = ref.read(userDatabaseProvider).trackDao;
    await dao.purgeHistory(track.id);
    await invalidateAfterTrackDataChange(ref, track.profileId);
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
