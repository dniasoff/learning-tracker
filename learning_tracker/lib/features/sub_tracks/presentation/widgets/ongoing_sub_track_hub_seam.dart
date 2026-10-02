import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
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
/// be saved." and a retry (UX-DR-121).
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
  final Set<String> _awaitingSync = {};
  StreamSubscription<List<PendingFailure>>? _failures;

  @override
  void dispose() {
    unawaited(_failures?.cancel());
    super.dispose();
  }

  Future<void> _add(OngoingSubTrackContext data) async {
    final choice = await showAddSubTrackChooser(context);
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
        existing: track,
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
    _awaitingSync.addAll(saved.changeIds);
    unawaited(_watchFailures());
  }

  Future<void> _watchFailures() async {
    if (_failures != null) return;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null || !mounted || _failures != null) return;
      _failures = commands.watchPendingFailures().listen(
        (failures) => _onFailures(commands, failures),
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

  void _onFailures(LearningCommands commands, List<PendingFailure> all) {
    if (!mounted) return;
    for (final failure in all) {
      if (!failure.changeIds.any(_awaitingSync.contains)) continue;
      _awaitingSync.removeAll(failure.changeIds);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.ongoingSubTrackSyncRejected),
          action: SnackBarAction(
            label: l10n.actionRetry,
            onPressed: () {
              _awaitingSync.addAll(failure.changeIds);
              unawaited(commands.retry(failure.id));
            },
          ),
        ),
      );
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
      AsyncData(value: final data?) when !data.calendarProgram => _section(
        context,
        data,
      ),
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
