import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_state.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_route.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_sub_track_chooser.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_start_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

final _log = AppLogger.instance;

/// DNI-495 SEAM — the minimal Sub-tracks group under one Manage tracks
/// curriculum card, owned by Story 2.5 (DNI-496) only because Story 2.4
/// (DNI-495, the Manage tracks hub) is not on `integ/sub-tracks`.
///
/// It shows, for a parent session on a non-calendar curriculum:
/// one outlined row per non-ended sub-track (a future-start row reads
/// "Starts {date}", AC-4) and *Add sub-track*, which opens the chooser and
/// the ongoing form. Ongoing rows open their edit form (AC-6).
///
/// After a save that was queued offline it watches the commands' pending
/// failures: a create or edit the server later refuses for good (for
/// example a sixth ongoing create from a second offline device, AD-45) is
/// rolled back by the local cache and announced with "Your change couldn't
/// be saved." and a retry (UX-DR-121). That watch is bound to the learner
/// the write was made for and to the commands instance it was made
/// through: a profile switch, a lost parent session or a new commands
/// instance cancels it, forgets the queued ids and closes an open
/// rejection notice, so one learner's rejection (or its Retry) never shows
/// in another learner's hub.
///
/// When Story 2.4 lands, its `sub_track_hub_section.dart` replaces this
/// widget; it keeps [subTrackStartsLabel], [showAddSubTrackChooser] and
/// [openOngoingSubTrackForm] (follow-up bead).
class OngoingSubTrackHubSeam extends ConsumerStatefulWidget {
  const OngoingSubTrackHubSeam({super.key, required this.curriculumId});

  /// The curriculum's storage key.
  final String curriculumId;

  @override
  ConsumerState<OngoingSubTrackHubSeam> createState() =>
      _OngoingSubTrackHubSeamState();
}

class _OngoingSubTrackHubSeamState
    extends ConsumerState<OngoingSubTrackHubSeam> {
  /// The learner the pending-failure watch is bound to.
  LearnerScope? _watchScope;

  /// The commands instance the watch listens to.
  LearningCommands? _watchCommands;

  /// Queued change ids of [_watchScope] still awaiting their sync.
  final Set<String> _awaitingSync = {};
  StreamSubscription<List<PendingFailure>>? _failures;

  @override
  void initState() {
    super.initState();
    // Keeps both providers alive for the save-time reads below, and drops
    // the watch the moment either stops matching what it was bound to.
    ref
      ..listenManual(ongoingSubTrackWriteScopeProvider, (_, next) {
        if (_watchScope == null || next.isLoading) return;
        if (next.hasError || next.value != _watchScope) _unbind();
      })
      ..listenManual(learningCommandsProvider, (_, next) {
        if (_watchCommands == null || next.isLoading) return;
        if (next.hasError || !identical(next.value, _watchCommands)) {
          _unbind();
        }
      });
  }

  @override
  void dispose() {
    unawaited(_failures?.cancel());
    super.dispose();
  }

  /// Whether the parent session still grants [scope], settled (fails
  /// closed while it reloads or on error).
  bool _grantHolds(LearnerScope scope) {
    final grant = ref.read(ongoingSubTrackWriteScopeProvider);
    return !grant.hasError && !grant.isLoading && grant.value == scope;
  }

  /// Whether the watch is still bound to [scope] and [commands], and both
  /// are still the active ones.
  bool _boundTo(LearnerScope scope, LearningCommands commands) {
    if (_watchScope != scope || !identical(_watchCommands, commands)) {
      return false;
    }
    final current = ref.read(learningCommandsProvider);
    return _grantHolds(scope) &&
        !current.hasError &&
        !current.isLoading &&
        identical(current.value, commands);
  }

  /// Cancels the pending-failure watch and forgets its learner's queued ids.
  void _unbind() {
    unawaited(_failures?.cancel());
    _failures = null;
    _watchScope = null;
    _watchCommands = null;
    _awaitingSync.clear();
  }

  Future<void> _add(OngoingSubTrackContext data) async {
    final choice = await showAddSubTrackChooser(
      context,
      ongoingInUse: data.ongoingInUse(),
    );
    if (choice != AddSubTrackChoice.ongoing || !mounted) return;
    _afterSave(
      await openOngoingSubTrackForm(context, curriculumId: widget.curriculumId),
    );
  }

  Future<void> _edit(SubTrack track) async {
    _afterSave(
      await openOngoingSubTrackForm(
        context,
        curriculumId: widget.curriculumId,
        subTrackId: track.id,
      ),
    );
  }

  void _afterSave(OngoingSubTrackSaved? saved) {
    if (saved == null || !saved.queued || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.ongoingSubTrackSavedOffline,
        ),
      ),
    );
    // Watch only for the learner the write was made for, and only while
    // it is still the granted one.
    if (!_grantHolds(saved.scope)) return;
    if (_watchScope != saved.scope) _unbind();
    _watchScope = saved.scope;
    _awaitingSync.addAll(saved.changeIds);
    unawaited(_watchFailures(saved.scope));
  }

  Future<void> _watchFailures(LearnerScope scope) async {
    if (_failures != null) return;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null || !mounted || _failures != null) return;
      if (_watchScope != scope || !_grantHolds(scope)) {
        if (_watchScope == scope) _unbind();
        return;
      }
      _watchCommands = commands;
      _failures = commands.watchPendingFailures().listen(
        (failures) => _onFailures(scope, commands, failures),
        onError: (Object error, StackTrace stack) => _log.error(
          event: 'ongoing_sub_track_pending_failures_failed',
          exception: error,
          stackTrace: stack,
        ),
      );
    } on Object catch (error, stack) {
      _log.error(
        event: 'ongoing_sub_track_pending_failures_unavailable',
        exception: error,
        stackTrace: stack,
      );
    }
  }

  void _onFailures(
    LearnerScope scope,
    LearningCommands commands,
    List<PendingFailure> all,
  ) {
    if (!mounted) return;
    if (!_boundTo(scope, commands)) {
      // Another learner (or commands instance) is active now.
      if (_watchScope == scope) _unbind();
      return;
    }
    for (final failure in all) {
      if (!failure.changeIds.any(_awaitingSync.contains)) continue;
      _awaitingSync.removeAll(failure.changeIds);
      _showRejected(scope, commands, failure);
    }
  }

  /// "Your change couldn't be saved." with a Retry of [failure].
  void _showRejected(
    LearnerScope scope,
    LearningCommands commands,
    PendingFailure failure,
  ) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _SyncRejectedNotice(
          scope: scope,
          text: l10n.ongoingSubTrackSyncRejected,
        ),
        action: SnackBarAction(
          label: l10n.actionRetry,
          onPressed: () => unawaited(_retry(scope, commands, failure)),
        ),
      ),
    );
  }

  /// Retries [failure] and keeps the user's recovery path (AC-7): a retry
  /// refused at once shows the notice again, whether the commands
  /// re-publish the failure (the watch shows it) or only answer it (shown
  /// here); a queued retry stays watched for a later refusal. Whichever
  /// path sees it first takes the change ids, so it is announced once.
  Future<void> _retry(
    LearnerScope scope,
    LearningCommands commands,
    PendingFailure failure,
  ) async {
    // Retry only for the learner and commands it was raised for.
    if (!mounted || !_boundTo(scope, commands)) return;
    _awaitingSync.addAll(failure.changeIds);
    CaptureResult result;
    try {
      result = await commands.retry(failure.id);
    } on Object catch (error, stack) {
      _log.error(
        event: 'ongoing_sub_track_retry_failed',
        exception: error,
        stackTrace: stack,
      );
      result = const CaptureResult.rejected(CaptureRejection.notSaved);
    }
    if (!mounted || !_boundTo(scope, commands)) return;
    switch (result) {
      case CaptureSuccess(queued: true):
        // Still awaiting the server: the watch announces a later refusal.
        return;
      case CaptureSuccess():
      case CaptureRejected(reason: CaptureRejection.targetNotFound):
        // Saved, or nothing left to retry (settled elsewhere).
        _awaitingSync.removeAll(failure.changeIds);
      default:
        if (!failure.changeIds.any(_awaitingSync.contains)) return;
        _awaitingSync.removeAll(failure.changeIds);
        _showRejected(scope, commands, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(ongoingSubTrackParentSessionProvider);
    if (session.value != true) return const SizedBox.shrink();
    final dataAsync = ref.watch(
      ongoingSubTrackContextProvider(widget.curriculumId),
    );
    return switch (dataAsync) {
      // A reload (new rows, the learner's midnight) keeps the last read.
      AsyncValue(value: final data?)
          when !dataAsync.hasError && !data.calendarProgram =>
        _section(context, data),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 12),
        child: InlineAsyncError(
          error: error,
          onRetry: () => ref.invalidate(
            ongoingSubTrackContextProvider(widget.curriculumId),
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _section(BuildContext context, OngoingSubTrackContext data) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('ongoingSubTrackHub-${widget.curriculumId}'),
      padding: const EdgeInsetsDirectional.only(start: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.ongoingSubTrackHubHeader,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.brandInk,
            ),
          ),
          for (final track in data.liveSubTracks)
            _row(context, l10n, track, data),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('ongoingSubTrackHubAdd'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => unawaited(_add(data)),
              icon: const Icon(Icons.add),
              label: Text(l10n.ongoingSubTrackChooserTitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    SubTrack track,
    OngoingSubTrackContext data,
  ) {
    final status =
        subTrackStartsLabel(context, track, data.today) ??
        l10n.ongoingSubTrackRateSummary(
          formatOngoingNumber(track.ratePerWeek),
          formatOngoingNumber(track.weeksPerYear),
        );
    return Card(
      key: ValueKey('ongoingSubTrackRow-${track.id}'),
      elevation: 0,
      margin: const EdgeInsetsDirectional.only(top: 8),
      color: context.colors.brandCreamCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colors.brandOutline),
      ),
      child: ListTile(
        minTileHeight: 56,
        title: Text(track.name),
        subtitle: Text(status),
        trailing: track.type == SubTrackType.ongoing
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: track.type == SubTrackType.ongoing
            ? () => unawaited(_edit(track))
            : null,
      ),
    );
  }
}

/// The "couldn't be saved" notice of one learner's rejected queued write.
/// It dismisses itself as soon as the parent session no longer grants
/// that learner (a profile switch or a lost session), so it never lingers
/// in another learner's hub. Only the showing snackbar is built, so hiding
/// the current one hides exactly this notice.
class _SyncRejectedNotice extends ConsumerStatefulWidget {
  const _SyncRejectedNotice({required this.scope, required this.text});

  final LearnerScope scope;
  final String text;

  @override
  ConsumerState<_SyncRejectedNotice> createState() =>
      _SyncRejectedNoticeState();
}

class _SyncRejectedNoticeState extends ConsumerState<_SyncRejectedNotice> {
  bool _hiding = false;

  @override
  Widget build(BuildContext context) {
    final grant = ref.watch(ongoingSubTrackWriteScopeProvider);
    final lost =
        grant.hasError ||
        (!grant.isLoading && grant.hasValue && grant.value != widget.scope);
    if (lost && !_hiding) {
      _hiding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      });
    }
    return Text(widget.text);
  }
}
