/// *+1* on a sub-track row (Story 2.9, DNI-500 T3, AC-2 / AC-5).
///
/// Records one `learn` event through `LearningCommands`, which runs
/// `CaptureGate` first (AD-36): `ref` = the engine's current position,
/// `source` = the sub-track ULID, `date_state = dated`, no `stage`, and
/// `learned_on` left to the command's default — the learner's civil today
/// (DNI-469 AC-2). Sub-track events never carry a `pts_` entry (AD-50); the
/// command owns that rule. A tutor device never writes here (UX-DR-158).
///
/// Production wiring: this reads `learningCommandsProvider`, the C0
/// (DNI-524) seam that DNI-469 fills. While it is still the C0 stub every
/// *+1* returns [PlusOneFailed] and writes nothing. DNI-500 does not fill
/// it (orchestrator rule: build and test against the C0 seam). The stub
/// cannot ship: `tool/retired_symbols/R15.json` makes DNI-490 remove every
/// `c0Stub` call before the cutover release. The no-override integration
/// test follows in bead learning-tracker-fyh.135.
///
/// Queued writes (AD-30, UX-DR-107/147): a *+1* or *Undo* the server has not
/// yet acknowledged returns `success(queued: true)`. The controller keeps
/// those event ids and, from the first one, follows
/// `LearningCommands.watchPendingFailures`. When the server later refuses one
/// for good it becomes a [SubTrackNotSaved] entry ("not saved — retry"): the
/// awaiting state for its events is dropped (the engine rolls the optimistic
/// write back) and [SubTrackCaptureController.retryNotSaved] re-sends it.
/// *Undo* clears its tracking only after the void is confirmed or queued; a
/// refused or failed undo leaves the capture tracked and says so.
///
/// Learner scope: `learningCommandsProvider` yields commands bound to one
/// `LearnerScope` and session actor, so the controller is bound to the
/// commands instance it first used. When that instance is replaced (another
/// learner, a tutored session entered or left, or no learner) every piece
/// of session state is dropped: in-flight and awaited captures, queued
/// writes, "not saved" entries and the pending-failure subscription. A
/// write that settles after the switch, an *Undo* of a capture this binding
/// did not make, and a *Retry* whose commands are not the ones that
/// reported the failure are refused, so nothing of one learner is shown to,
/// or re-sent under, another.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart'
    show subTrackWritesAllowedProvider;

/// What a *+1* tap did.
sealed class PlusOneOutcome {
  const PlusOneOutcome();
}

/// One event was recorded (or queued offline); [eventIds] undo it.
final class PlusOneRecorded extends PlusOneOutcome {
  /// Creates the outcome.
  const PlusOneRecorded(this.eventIds);

  /// The captured event ids.
  final List<String> eventIds;
}

/// The capture gate refused the write: nothing was written. The lock
/// overlay already covers the app (AD-36), so no message is shown.
final class PlusOneLocked extends PlusOneOutcome {
  /// Creates the outcome.
  const PlusOneLocked();
}

/// The command refused or failed; nothing to undo.
final class PlusOneFailed extends PlusOneOutcome {
  /// Creates the outcome.
  const PlusOneFailed();
}

/// The tap was not acted on: a *+1* for the row is already in flight, the
/// row cannot capture, the viewer is a tutor, or the learner changed before
/// it settled (the write then belongs to the previous learner and this
/// session offers no *Undo* for it).
final class PlusOneIgnored extends PlusOneOutcome {
  /// Creates the outcome.
  const PlusOneIgnored();
}

/// What an *Undo* did.
enum UndoOutcome {
  /// The void was recorded (or queued offline).
  undone,

  /// The capture gate refused it; the lock overlay covers the app.
  locked,

  /// The command refused it for good (e.g. a lock-ignored target), or the
  /// capture was not made under the current learner: the capture stands
  /// and retrying would not help.
  refused,

  /// It did not go through (no commands, a throw, offline-only refusal):
  /// the capture stands and the learner may retry.
  failed,
}

/// Which write a [SubTrackNotSaved] entry is about.
enum SubTrackWriteKind {
  /// A *+1* capture.
  plusOne,

  /// The void of a *+1* (its *Undo*).
  undo,
}

/// A queued *+1* or *Undo* the server refused for good: "not saved — retry"
/// (AD-30, UX-DR-107/147).
final class SubTrackNotSaved {
  /// Creates the entry.
  const SubTrackNotSaved({
    required this.failureId,
    required this.kind,
    required this.subTrackId,
    required this.subTrackName,
    required this.eventIds,
  });

  /// The `PendingFailure` id (passed to `LearningCommands.retry`).
  final String failureId;

  /// Whether the refused write was a *+1* or its *Undo*.
  final SubTrackWriteKind kind;

  /// The sub-track it was written for.
  final String subTrackId;

  /// The sub-track's name when it was written.
  final String subTrackName;

  /// This controller's events in the refused write.
  final List<String> eventIds;

  @override
  bool operator ==(Object other) =>
      other is SubTrackNotSaved &&
      other.failureId == failureId &&
      other.kind == kind &&
      other.subTrackId == subTrackId &&
      other.subTrackName == subTrackName &&
      _sameList(other.eventIds, eventIds);

  @override
  int get hashCode => Object.hash(
    failureId,
    kind,
    subTrackId,
    subTrackName,
    Object.hashAll(eventIds),
  );

  @override
  String toString() => 'SubTrackNotSaved($failureId, ${kind.name})';
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A queued write this controller made: what it was and for which track.
final class _QueuedWrite {
  const _QueuedWrite(this.kind, this.subTrackId, this.subTrackName);

  final SubTrackWriteKind kind;
  final String subTrackId;
  final String subTrackName;
}

/// The controller's state.
final class SubTrackCaptureState {
  /// Creates a state.
  const SubTrackCaptureState({
    this.inFlight = const {},
    this.awaitingEngine = const {},
    this.notSaved = const [],
  });

  /// Sub-track ids with a *+1* in flight.
  final Set<String> inFlight;

  /// Event ids captured this session that the engine has neither counted
  /// nor lock-ignored yet (AC-5).
  final Set<String> awaitingEngine;

  /// Queued writes of this session the server refused for good, oldest
  /// first, until retried or resolved elsewhere.
  final List<SubTrackNotSaved> notSaved;

  SubTrackCaptureState _copy({
    Set<String>? inFlight,
    Set<String>? awaitingEngine,
    List<SubTrackNotSaved>? notSaved,
  }) => SubTrackCaptureState(
    inFlight: inFlight ?? this.inFlight,
    awaitingEngine: awaitingEngine ?? this.awaitingEngine,
    notSaved: notSaved ?? this.notSaved,
  );
}

/// Records *+1* and *Undo*, and spots captures the engine later finds
/// lock-stamped.
class SubTrackCaptureController extends Notifier<SubTrackCaptureState> {
  /// Queued event ids of this session, until confirmed or voided.
  final Map<String, _QueuedWrite> _queued = {};

  /// Event ids captured under [_bound] and not yet undone: the only ones
  /// *Undo* may void.
  final Set<String> _captured = {};

  /// The commands (one learner scope and session actor) this session's
  /// state belongs to; null until first used.
  LearningCommands? _bound;

  /// Bumped whenever [_bound] is replaced; an operation that started under
  /// an older binding never touches the new state.
  int _binding = 0;

  LearningCommands? _watched;
  StreamSubscription<List<PendingFailure>>? _failures;

  @override
  SubTrackCaptureState build() {
    ref
      ..onDispose(_stopWatching)
      ..listen(learningCommandsProvider, (_, next) {
        // A reload keeps the previous value; only a different instance (or
        // no learner) is a scope change.
        final commands = next.value;
        if (next.hasValue && _bound != null && !identical(commands, _bound)) {
          _rebind(commands);
        }
      });
    return const SubTrackCaptureState();
  }

  /// Drops every piece of state of the previous binding and binds to
  /// [commands].
  void _rebind(LearningCommands? commands) {
    AppLogger.instance.info(event: 'sub_track_capture_scope_changed');
    _binding++;
    _stopWatching();
    _queued.clear();
    _captured.clear();
    _bound = commands;
    state = const SubTrackCaptureState();
  }

  /// Binds to [commands] (first use) or rebinds when they replaced the
  /// bound ones, then reports whether [binding] is still current.
  bool _stillBound(LearningCommands commands, int binding) {
    if (_bound == null) {
      _bound = commands;
    } else if (!identical(_bound, commands)) {
      _rebind(commands);
    }
    return binding == _binding;
  }

  void _stopWatching() {
    unawaited(_failures?.cancel());
    _failures = null;
    _watched = null;
  }

  /// Remembers queued [eventIds] and follows [commands]' pending failures.
  void _trackQueued(
    LearningCommands commands,
    List<String> eventIds,
    _QueuedWrite write,
  ) {
    for (final id in eventIds) {
      _queued[id] = write;
    }
    if (identical(_watched, commands)) return;
    _stopWatching();
    _watched = commands;
    _failures = commands.watchPendingFailures().listen(
      _onPendingFailures,
      onError: (Object e, StackTrace st) => AppLogger.instance.error(
        event: 'sub_track_pending_failures_failed',
        exception: e,
        stackTrace: st,
      ),
    );
  }

  /// Turns the server's permanent refusals of this session's queued writes
  /// into [SubTrackCaptureState.notSaved] entries, and drops entries whose
  /// failure has been resolved elsewhere.
  void _onPendingFailures(List<PendingFailure> failures) {
    final live = {for (final f in failures) f.id};
    final known = {for (final n in state.notSaved) n.failureId};
    final added = <SubTrackNotSaved>[];
    final rolledBack = <String>{};
    for (final failure in failures) {
      if (known.contains(failure.id)) continue;
      final mine = [
        for (final id in failure.eventIds)
          if (_queued.containsKey(id)) id,
      ];
      if (mine.isEmpty) continue;
      final write = _queued[mine.first]!;
      added.add(
        SubTrackNotSaved(
          failureId: failure.id,
          kind: write.kind,
          subTrackId: write.subTrackId,
          subTrackName: write.subTrackName,
          eventIds: mine,
        ),
      );
      if (write.kind == SubTrackWriteKind.plusOne) rolledBack.addAll(mine);
    }
    final kept = [
      for (final n in state.notSaved)
        if (live.contains(n.failureId)) n,
    ];
    if (added.isEmpty && kept.length == state.notSaved.length) return;
    // A refused capture never reaches the engine: it is not awaited any more.
    state = state._copy(
      awaitingEngine: rolledBack.isEmpty
          ? null
          : ({...state.awaitingEngine}..removeAll(rolledBack)),
      notSaved: [...kept, ...added],
    );
  }

  /// Records [item]'s current position in [item]'s track.
  Future<PlusOneOutcome> plusOne(SubTrackHomeItem item) async {
    final position = item.position;
    if (!item.canCapture ||
        position == null ||
        state.inFlight.contains(item.subTrackId) ||
        // Story 4.2 (AC-1, AC-5, AC-6): a tutor records through his tutor
        // commands only while he may write now.
        !ref.read(subTrackWritesAllowedProvider)) {
      return const PlusOneIgnored();
    }
    final binding = _binding;
    state = state._copy(inFlight: {...state.inFlight, item.subTrackId});
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) return const PlusOneFailed();
      // The row was another learner's: never write it under this one.
      if (!_stillBound(commands, binding)) return const PlusOneIgnored();
      final result = await commands.capture(
        curriculumId: item.curriculumId,
        refs: [position],
        source: item.subTrackId,
        dateState: DateState.dated,
        gesture: CaptureGesture.plusOne,
        taps: 1,
      );
      if (binding != _binding) {
        AppLogger.instance.warning(
          event: 'sub_track_plus_one_settled_after_scope_change',
        );
        return const PlusOneIgnored();
      }
      switch (result) {
        case CaptureSuccess(:final eventIds, :final queued):
          _captured.addAll(eventIds);
          state = state._copy(
            awaitingEngine: {...state.awaitingEngine, ...eventIds},
          );
          if (queued) {
            _trackQueued(
              commands,
              eventIds,
              _QueuedWrite(
                SubTrackWriteKind.plusOne,
                item.subTrackId,
                item.name,
              ),
            );
          }
          return PlusOneRecorded(eventIds);
        case CaptureLocked():
          return const PlusOneLocked();
        case CaptureChildLimit() ||
            CaptureOnlineRequired() ||
            CaptureRejected():
          AppLogger.instance.warning(
            event: 'sub_track_plus_one_refused',
            fields: {'result': result.runtimeType.toString()},
          );
          return const PlusOneFailed();
      }
    } on Object catch (e, st) {
      AppLogger.instance.error(
        event: 'sub_track_plus_one_failed',
        exception: e,
        stackTrace: st,
      );
      return const PlusOneFailed();
    } finally {
      if (binding == _binding) {
        state = state._copy(
          inFlight: {...state.inFlight}..remove(item.subTrackId),
        );
      }
    }
  }

  /// Voids the events of [item]'s *+1* (the snackbar's *Undo*,
  /// UX-DR-154). The capture stays tracked unless the void is confirmed or
  /// queued, so a refused or failed undo can be reported and retried.
  /// Only captures made under the current learner are voided; any other
  /// *Undo* is [UndoOutcome.refused] without a write.
  Future<UndoOutcome> undo(SubTrackHomeItem item, List<String> eventIds) async {
    final binding = _binding;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) return UndoOutcome.failed;
      if (!_stillBound(commands, binding) ||
          !eventIds.every(_captured.contains)) {
        AppLogger.instance.warning(
          event: 'sub_track_plus_one_undo_out_of_scope',
        );
        return UndoOutcome.refused;
      }
      final result = await commands.undoEvents(eventIds);
      if (binding != _binding) return UndoOutcome.refused;
      switch (result) {
        case CaptureSuccess(eventIds: final voidIds, :final queued):
          _captured.removeAll(eventIds);
          for (final id in eventIds) {
            _queued.remove(id);
          }
          state = state._copy(
            awaitingEngine: {...state.awaitingEngine}..removeAll(eventIds),
            notSaved: [
              for (final n in state.notSaved)
                if (!n.eventIds.any(eventIds.contains)) n,
            ],
          );
          if (queued) {
            _trackQueued(
              commands,
              voidIds,
              _QueuedWrite(SubTrackWriteKind.undo, item.subTrackId, item.name),
            );
          }
          return UndoOutcome.undone;
        case CaptureLocked():
          return UndoOutcome.locked;
        case CaptureRejected():
          AppLogger.instance.warning(
            event: 'sub_track_plus_one_undo_refused',
            fields: {'result': result.toString()},
          );
          return UndoOutcome.refused;
        case CaptureChildLimit() || CaptureOnlineRequired():
          AppLogger.instance.warning(
            event: 'sub_track_plus_one_undo_refused',
            fields: {'result': result.runtimeType.toString()},
          );
          return UndoOutcome.failed;
      }
    } on Object catch (e, st) {
      AppLogger.instance.error(
        event: 'sub_track_plus_one_undo_failed',
        exception: e,
        stackTrace: st,
      );
      return UndoOutcome.failed;
    }
  }

  /// Re-sends the refused write [failureId] (the "not saved" *Retry*). The
  /// entry goes once the retry is accepted or queued again; a re-sent *+1*
  /// is awaited from the engine again (same event ids). Returns whether the
  /// retry went through.
  Future<bool> retryNotSaved(String failureId) async {
    final entry = state.notSaved
        .where((n) => n.failureId == failureId)
        .firstOrNull;
    if (entry == null) return false;
    final binding = _binding;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) return false;
      // Only the commands that reported the failure may re-send it.
      if (!_stillBound(commands, binding) || !identical(commands, _watched)) {
        AppLogger.instance.warning(
          event: 'sub_track_not_saved_retry_out_of_scope',
        );
        return false;
      }
      final result = await commands.retry(failureId);
      if (binding != _binding) return false;
      if (result is! CaptureSuccess) {
        AppLogger.instance.warning(
          event: 'sub_track_not_saved_retry_refused',
          fields: {'result': result.runtimeType.toString()},
        );
        return false;
      }
      state = state._copy(
        awaitingEngine: entry.kind == SubTrackWriteKind.plusOne
            ? {...state.awaitingEngine, ...entry.eventIds}
            : null,
        notSaved: [
          for (final n in state.notSaved)
            if (n.failureId != failureId) n,
        ],
      );
      return true;
    } on Object catch (e, st) {
      AppLogger.instance.error(
        event: 'sub_track_not_saved_retry_failed',
        exception: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Settles the captures the engine has now decided on, returning those it
  /// found lock-stamped: they stay stored but do not count (AD-36,
  /// `prd-deviations` #2), and the caller tells the learner once (AC-5).
  List<String> reconcile(LearnerState engine) {
    if (state.awaitingEngine.isEmpty) return const [];
    final lockIgnored = [
      for (final id in state.awaitingEngine)
        if (engine.lockIgnoredEventIds.contains(id)) id,
    ];
    final settled = {
      ...lockIgnored,
      for (final id in state.awaitingEngine)
        if (engine.countedEventIds.contains(id)) id,
    };
    if (settled.isNotEmpty) {
      state = state._copy(
        awaitingEngine: {...state.awaitingEngine}..removeAll(settled),
      );
    }
    return lockIgnored;
  }
}

/// The app-wide *+1* controller (kept alive so a capture in flight, and its
/// lock check after sync, outlive the Learn tab's rebuilds). Its state is
/// bound to the active learner's commands and reset when they change.
final subTrackCaptureControllerProvider =
    NotifierProvider<SubTrackCaptureController, SubTrackCaptureState>(
      SubTrackCaptureController.new,
    );
