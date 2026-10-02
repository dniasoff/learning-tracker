/// The shared feedback of every owner capture surface (Story 1.11,
/// DNI-473): the Undo snackbar after a recorded batch (UX-DR-154) and the
/// "not saved — retry" snackbar for a write the server rejected for good
/// (UX-DR-107, UX-DR-147, AD-54 Recovery).
///
/// Presentation only: the policy (what a capture writes, what Undo voids,
/// what a retry re-sends) lives in `LearningCommands`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the snackbar of a finished capture and returns the ids it wrote.
///
/// * A [CaptureSuccess] that wrote events shows [message] with an Undo
///   action. Undo voids exactly those events through
///   [LearningCommands.undoEvents] — never an earlier one — and then calls
///   [onUndone]; an undo that does not save shows the "not saved" notice.
/// * A [CaptureSuccess] with [CaptureSuccess.keptNotCounted] events (a tutor
///   capture the server stamped inside the learner's lock, DNI-486 AC-7)
///   shows "Kept, not counted — Shabbos / Yom Tov had started"; Undo covers
///   only the counted events.
/// * A [CaptureLocked] result shows the lock notice: nothing was written
///   (the full-screen lock overlay normally covers the app first).
/// * A batch the server rejected for good ([CaptureRejection.notSaved]) shows
///   nothing here: it is a pending failure, which the screen's
///   [PendingCaptureFailureListener] announces once with Retry.
/// * Any other result shows the "not saved" notice.
///
/// [messenger] defaults to the one above [context]; pass it explicitly when
/// the caller navigates away right after (the root messenger outlives the
/// route).
List<String> showCaptureOutcome(
  BuildContext context, {
  required CaptureResult result,
  required LearningCommands commands,
  required String message,
  VoidCallback? onUndone,
  ScaffoldMessengerState? messenger,
}) {
  final l10n = AppLocalizations.of(context)!;
  final target = messenger ?? ScaffoldMessenger.of(context);
  final warningFill = context.colors.warningSnackbarFill;
  switch (result) {
    case CaptureSuccess(keptNotCounted: [_, ...]):
      // AD-36 / DNI-486 AC-7: a tutor capture stamped inside the learner's
      // lock is stored but not counted. It is not rolled back and no Undo
      // is offered for it; only the counted events can be undone.
      final counted = result.countedEventIds;
      target.showSnackBar(
        SnackBar(
          content: Text(l10n.tutorCaptureKeptNotCounted),
          duration: const Duration(seconds: 6),
          persist: false,
          action: counted.isEmpty
              ? null
              : SnackBarAction(
                  label: l10n.undoLabel,
                  onPressed: () => unawaited(
                    _undo(
                      commands,
                      counted,
                      target,
                      l10n,
                      warningFill,
                      onUndone,
                    ),
                  ),
                ),
        ),
      );
      return counted;
    case CaptureSuccess(:final eventIds):
      target.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          // The Undo window closes on its own; a failure notice persists.
          persist: false,
          action: eventIds.isEmpty
              ? null
              : SnackBarAction(
                  label: l10n.undoLabel,
                  onPressed: () => unawaited(
                    _undo(
                      commands,
                      eventIds,
                      target,
                      l10n,
                      warningFill,
                      onUndone,
                    ),
                  ),
                ),
        ),
      );
      return eventIds;
    case CaptureLocked():
      target.showSnackBar(SnackBar(content: Text(l10n.captureLockedNotice)));
      return const [];
    case CaptureRejected(reason: CaptureRejection.notSaved):
      // The rejected batch is now a pending failure: the screen's
      // [PendingCaptureFailureListener] announces it once, with Retry.
      return const [];
    case CaptureChildLimit() || CaptureOnlineRequired() || CaptureRejected():
      target.showSnackBar(
        SnackBar(
          content: Text(l10n.captureNotSaved),
          backgroundColor: warningFill,
        ),
      );
      return const [];
  }
}

Future<void> _undo(
  LearningCommands commands,
  List<String> eventIds,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  Color warningFill,
  VoidCallback? onUndone,
) async {
  final CaptureResult result;
  try {
    result = await commands.undoEvents(eventIds);
  } on Exception {
    _notSaved(messenger, l10n, warningFill);
    return;
  }
  if (result is CaptureSuccess) {
    onUndone?.call();
  } else {
    _notSaved(messenger, l10n, warningFill);
  }
}

void _notSaved(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  Color warningFill,
) {
  if (!messenger.mounted) return;
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.captureNotSaved), backgroundColor: warningFill),
  );
}

/// The failure ids already announced by some mounted
/// [PendingCaptureFailureListener], so two capture screens on the stack do
/// not both announce one failure.
final announcedCaptureFailuresProvider =
    NotifierProvider<AnnouncedCaptureFailures, Set<String>>(
      AnnouncedCaptureFailures.new,
    );

/// See [announcedCaptureFailuresProvider].
class AnnouncedCaptureFailures extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Marks [id] announced; false when it already was.
  bool announce(String id) {
    if (state.contains(id)) return false;
    state = {...state, id};
    return true;
  }

  /// Forgets [id], so its next rejection is announced again.
  void forget(String id) => state = {...state}..remove(id);
}

/// Listens to the active learner's pending failures (AD-54 Recovery) while
/// [child] is mounted.
///
/// Every new failure calls [onFailure] once, so the screen can roll back
/// the optimistic state of exactly those event ids; the first listener to
/// see it also shows "not saved" with Retry. Retry re-sends the same
/// immutable chunk (same ULIDs and timestamps) through
/// [LearningCommands.retry]; a retry the server acknowledges calls
/// [onRetried] so the screen can re-apply that state, and a retry that is
/// rejected again comes back as a new announcement.
class PendingCaptureFailureListener extends ConsumerStatefulWidget {
  /// Creates the listener.
  const PendingCaptureFailureListener({
    super.key,
    required this.child,
    this.onFailure,
    this.onRetried,
  });

  /// The screen.
  final Widget child;

  /// A failure was reported (roll back its optimistic state).
  final void Function(PendingFailure failure)? onFailure;

  /// A retry of a failure was saved (re-apply its state).
  final void Function(PendingFailure failure)? onRetried;

  @override
  ConsumerState<PendingCaptureFailureListener> createState() =>
      _PendingCaptureFailureListenerState();
}

class _PendingCaptureFailureListenerState
    extends ConsumerState<PendingCaptureFailureListener> {
  StreamSubscription<List<PendingFailure>>? _subscription;
  LearningCommands? _commands;
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<LearningCommands?>>(
      learningCommandsProvider,
      (_, next) => _bind(next.asData?.value),
      fireImmediately: true,
    );
  }

  void _bind(LearningCommands? commands) {
    if (identical(commands, _commands)) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _seen.clear();
    _commands = commands;
    if (commands == null) return;
    _subscription = commands.watchPendingFailures().listen(
      _onFailures,
      onError: (Object _) {}, // a broken feed never breaks the screen
    );
  }

  void _onFailures(List<PendingFailure> failures) {
    if (!mounted) return;
    final current = {for (final f in failures) f.id};
    _seen.removeWhere((id) => !current.contains(id));
    for (final failure in failures) {
      if (!_seen.add(failure.id)) continue;
      widget.onFailure?.call(failure);
      final announced = ref
          .read(announcedCaptureFailuresProvider.notifier)
          .announce(failure.id);
      if (announced) _announce(failure);
    }
  }

  void _announce(PendingFailure failure) {
    final l10n = AppLocalizations.of(context)!;
    // The failure supersedes a showing "recorded — Undo" notice: that batch
    // was not saved, so its Undo is moot.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.captureNotSaved),
          backgroundColor: context.colors.warningSnackbarFill,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.actionRetry,
            onPressed: () => unawaited(_retry(failure)),
          ),
        ),
      );
  }

  Future<void> _retry(PendingFailure failure) async {
    final commands = _commands;
    if (commands == null) return;
    ref.read(announcedCaptureFailuresProvider.notifier).forget(failure.id);
    _seen.remove(failure.id);
    final CaptureResult result;
    try {
      result = await commands.retry(failure.id);
    } on Exception {
      return; // still pending: the feed re-announces it
    }
    if (mounted && result is CaptureSuccess) widget.onRetried?.call(failure);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
