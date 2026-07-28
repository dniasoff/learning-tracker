import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// TS-16: Returns true when Archive/Delete operations are allowed for the
/// track (i.e., the profile has more than one active curriculum).
///
/// When [activeCurriculumCount] <= 1, the track is the last active curriculum
/// and destructive actions must be gated rather than offered optimistically.
///
/// AUD-t-story-acceptance-04: this is the single source of truth for the
/// guard — TrackManagementHubScreen delegates its entire body to
/// [TrackManagementBody] rather than re-declaring this function.
bool trackDeletionAllowed({required int activeCurriculumCount}) {
  return activeCurriculumCount > 1;
}

/// Shared body widget for the track-management screens.
///
/// Wired into TrackManagementHubScreen (the child-mode, tab-root hub) via
/// `showBackButton: true` — the hub always renders an explicit back
/// affordance (pop to the caller when possible, otherwise navigate to
/// [LearningRoute]) so users are never stranded in track setup. A future
/// pushed-route caller that genuinely needs no leading affordance can pass
/// `showBackButton: false` (the default).
class TrackManagementBody extends ConsumerStatefulWidget {
  const TrackManagementBody({
    super.key,
    this.showBackButton = false,
    this.startAdding = false,
  });

  /// Whether to render a leading back-navigation button in the [AppBar].
  final bool showBackButton;

  /// Whether to show [AddTrackFlow] immediately on first build, bypassing
  /// the track list. Used by deep-link entry points (e.g. the
  /// empty-dashboard and skipped-onboarding CTAs that route to
  /// `TrackManagementHubRoute(startAdding: true)`).
  final bool startAdding;

  @override
  ConsumerState<TrackManagementBody> createState() =>
      _TrackManagementBodyState();
}

class _TrackManagementBodyState extends ConsumerState<TrackManagementBody> {
  late bool _addingTrack = widget.startAdding;

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
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        // Explicit back control: a tab-root hub previously had no leading
        // affordance, stranding the user in track setup with no way back to
        // learning. Pop to the caller when possible; otherwise go to the
        // Learning view.
        leading: widget.showBackButton
            ? IconButton(
                // AX-3 / AUD-tracks-17: `tooltip:` alone does not populate
                // `SemanticsData.label` on the current Flutter SDK (it only
                // sets `.tooltip`), so the Icon also carries
                // `semanticLabel`, which Flutter surfaces as
                // `Semantics(label:)` — the field TalkBack/VoiceOver read.
                icon: Icon(
                  Icons.arrow_back,
                  semanticLabel: MaterialLocalizations.of(
                    context,
                  ).backButtonTooltip,
                ),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  if (context.router.canPop()) {
                    context.router.maybePop();
                  } else {
                    context.router.navigate(const LearningRoute());
                  }
                },
              )
            : null,
        title: Text(
          l10n.manageTracks,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandBlueDeep,
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
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () => ref.refresh(activeTracksProvider),
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
      // darkmode/tracks audit: brandBlue is tested as an INK role (it
      // LIGHTENS in dark for ink-on-dark-card use) but was painted here as a
      // hero FILL with a hardcoded white icon/label on top — measured 2.52:1
      // in dark. trackAddFabFill keeps the exact brandBlue light hex but
      // stays deep in dark: 8.41:1 with white.
      backgroundColor: context.colors.trackAddFabFill,
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
              AppLocalizations.of(context)!.activeTracksRunning(activeCount),
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
            Text(l10n.noTracksYet, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              l10n.firstTrackPrompt,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _addingTrack = true),
              icon: const Icon(Icons.add),
              label: Text(l10n.addYourFirstTrack),
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

    // TS-16: Pre-check whether Archive/Delete is allowed before showing the
    // dialog. When this track is the only active curriculum, surfacing the
    // destructive actions would only produce a post-commit error snackbar.
    //
    // AUD-tracks-14 (DB-1): routed through curriculumActivationServiceProvider
    // (same provider the 'archive' branch below uses) instead of reading
    // userDatabaseProvider/trackDao directly from this widget.
    final activeCurricula = await ref
        .read(curriculumActivationServiceProvider)
        .getActiveCurricula();
    if (!mounted) return;

    final canDelete = trackDeletionAllowed(
      activeCurriculumCount: activeCurricula.length,
    );

    // 'archive' = keep history; 'wipe' = hard-delete completions; null = cancel
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTrackArchiveTitle),
        content: Text(
          canDelete
              ? l10n.deleteTrackArchiveBody
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

    // Every profile must keep at least one active curriculum. Use deactivate
    // (which throws LastActiveCurriculumException for the last curriculum)
    // rather than calling the DAO directly to bypass the invariant.
    if (choice == 'archive') {
      final curriculum = CurriculumId.values
          .where((c) => c.storageKey == track.curriculumId)
          .firstOrNull;
      if (curriculum != null) {
        try {
          await ref
              .read(curriculumActivationServiceProvider)
              .deactivate(curriculum);
          await onTrackChanged(ref, track.profileId);
        } on LastActiveCurriculumException {
          if (!mounted) return;
          _showLastCurriculumError(l10n);
        }
        return;
      }
    }

    // Wipe path: use the already-fetched active count (canDelete was true
    // since the dialog showed the wipe option). Defensive guard kept for
    // safety.
    if (!canDelete) {
      if (!mounted) return;
      _showLastCurriculumError(l10n);
      return;
    }

    // AUD-tracks-14 (DB-1): wipe goes through the same service the 'archive'
    // branch above uses, instead of pulling trackDao out of
    // userDatabaseProvider directly — including try/catch + a localized
    // error SnackBar for parity with the archive path's error handling.
    try {
      await ref
          .read(curriculumActivationServiceProvider)
          .purgeTrackHistory(track.id);
      await onTrackChanged(ref, track.profileId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric(e.toString()))));
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
