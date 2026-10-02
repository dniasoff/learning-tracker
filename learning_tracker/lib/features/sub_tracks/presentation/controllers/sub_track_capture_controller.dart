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
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';

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
/// row cannot capture, or the viewer is a tutor.
final class PlusOneIgnored extends PlusOneOutcome {
  /// Creates the outcome.
  const PlusOneIgnored();
}

/// The controller's state.
final class SubTrackCaptureState {
  /// Creates a state.
  const SubTrackCaptureState({
    this.inFlight = const {},
    this.awaitingEngine = const {},
  });

  /// Sub-track ids with a *+1* in flight.
  final Set<String> inFlight;

  /// Event ids captured this session that the engine has neither counted
  /// nor lock-ignored yet (AC-5).
  final Set<String> awaitingEngine;

  SubTrackCaptureState _copy({
    Set<String>? inFlight,
    Set<String>? awaitingEngine,
  }) => SubTrackCaptureState(
    inFlight: inFlight ?? this.inFlight,
    awaitingEngine: awaitingEngine ?? this.awaitingEngine,
  );
}

/// Records *+1* and *Undo*, and spots captures the engine later finds
/// lock-stamped.
class SubTrackCaptureController extends Notifier<SubTrackCaptureState> {
  @override
  SubTrackCaptureState build() => const SubTrackCaptureState();

  /// Records [item]'s current position in [item]'s track.
  Future<PlusOneOutcome> plusOne(SubTrackHomeItem item) async {
    final position = item.position;
    if (!item.canCapture ||
        position == null ||
        state.inFlight.contains(item.subTrackId) ||
        ref.read(subTrackViewerRoleProvider) == SubTrackViewerRole.tutor) {
      return const PlusOneIgnored();
    }
    state = state._copy(inFlight: {...state.inFlight, item.subTrackId});
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) return const PlusOneFailed();
      final result = await commands.capture(
        curriculumId: item.curriculumId,
        refs: [position],
        source: item.subTrackId,
        dateState: DateState.dated,
      );
      switch (result) {
        case CaptureSuccess(:final eventIds):
          state = state._copy(
            awaitingEngine: {...state.awaitingEngine, ...eventIds},
          );
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
      state = state._copy(
        inFlight: {...state.inFlight}..remove(item.subTrackId),
      );
    }
  }

  /// Voids the events of a *+1* (the snackbar's *Undo*, UX-DR-154).
  Future<bool> undo(List<String> eventIds) async {
    state = state._copy(
      awaitingEngine: {...state.awaitingEngine}..removeAll(eventIds),
    );
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) return false;
      return await commands.undoEvents(eventIds) is CaptureSuccess;
    } on Object catch (e, st) {
      AppLogger.instance.error(
        event: 'sub_track_plus_one_undo_failed',
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
/// lock check after sync, outlive the Learn tab's rebuilds).
final subTrackCaptureControllerProvider =
    NotifierProvider<SubTrackCaptureController, SubTrackCaptureState>(
      SubTrackCaptureController.new,
    );
