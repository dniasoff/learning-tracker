/// Mishna-history state (Story 1.13, DNI-475; FR-4, FR-30, AD-35).
///
/// - [mishnaHistoryProvider] projects the complete profile log
///   ([profileHistoryLogProvider]), the engine output
///   ([learnerStateProvider]) and the corpus ([corporaProvider]) into a
///   [MishnaHistory]. It is loading until every input is complete and
///   forwards any input failure, so the screen can retry.
/// - [mishnaHistoryCorrectionsProvider] owns optimistic corrections: a row
///   changes at once, the write goes through [LearningCommands]
///   (`voidEvent` / `replace`), and a refused or failed write removes the
///   overlay — restoring the original row — before the caller shows the
///   rollback snackbar (UX-DR-142). A successful write keeps the overlay
///   until the refreshed history confirms it; a queued (offline) write the
///   server later rejects (`watchPendingFailures`) rolls back then, counted
///   in [MishnaHistoryCorrectionsState.lateRollbacks] for the snackbar.
/// - [mishnaHistoryLockProvider] is the AD-36 lock of the learner whose
///   history is shown: that learner's [learnerLockSettingsProvider] judged
///   by the shared [captureGateProvider], so a tutor or another profile on
///   this device sees the target learner's lock, not only the device's.
///
/// Plain Riverpod providers (no codegen), matching the C0 provider style.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/profile_history_log_source.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// The history route's arguments: a curriculum storage key and leaf ref.
typedef MishnaHistoryArgs = ({String curriculumId, LeafRef leafRef});

/// Thrown into the history state when no learner is active.
final class NoActiveLearnerException implements Exception {
  /// Creates the exception.
  const NoActiveLearnerException();

  @override
  String toString() => 'NoActiveLearnerException';
}

/// The viewer role of the active session.
///
/// A tutored session is [MishnaHistoryViewer.tutor]; a child-mode profile
/// is [MishnaHistoryViewer.child]; any other profile is
/// [MishnaHistoryViewer.parent]. While the profile is still loading the
/// role is child, the most limited one (fail closed). `LearningCommands`
/// enforces the real child limits whatever this returns.
final mishnaHistoryViewerProvider = Provider.autoDispose<MishnaHistoryViewer>((
  ref,
) {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
    return MishnaHistoryViewer.tutor;
  }
  final profile = ref.watch(activeProfileProvider);
  if (!profile.hasValue) return MishnaHistoryViewer.child;
  return profile.value?.mode == ProfileMode.child
      ? MishnaHistoryViewer.child
      : MishnaHistoryViewer.parent;
});

/// The [MishnaHistory] of [MishnaHistoryArgs] for the active learner.
final mishnaHistoryProvider = Provider.autoDispose
    .family<AsyncValue<MishnaHistory>, MishnaHistoryArgs>((ref, args) {
      final scope = ref.watch(activeLearnerScopeProvider);
      if (scope case AsyncError(:final error, :final stackTrace)) {
        return AsyncError<MishnaHistory>(error, stackTrace);
      }
      if (!scope.hasValue) return const AsyncLoading<MishnaHistory>();
      final active = scope.requireValue;
      if (active == null) {
        return AsyncError<MishnaHistory>(
          const NoActiveLearnerException(),
          StackTrace.current,
        );
      }

      final log = ref.watch(profileHistoryLogProvider(active));
      final state = ref.watch(learnerStateProvider(active));
      final corpora = ref.watch(corporaProvider);
      for (final input in <AsyncValue<Object?>>[log, state, corpora]) {
        if (input case AsyncError(:final error, :final stackTrace)) {
          return AsyncError<MishnaHistory>(error, stackTrace);
        }
      }
      if (!log.hasValue || !state.hasValue || !corpora.hasValue) {
        return const AsyncLoading<MishnaHistory>();
      }
      return AsyncData(
        MishnaHistory.project(
          curriculumId: args.curriculumId,
          leafRef: args.leafRef,
          log: log.requireValue,
          state: state.requireValue,
          corpus: corpora.requireValue[args.curriculumId],
        ),
      );
    });

/// How often [mishnaHistoryLockProvider] re-judges the lock against the
/// clock, so the history hides when the learner's lock starts and returns
/// when it ends without any other input changing. Same resolution as the
/// device lock (`CurrentSacredWindow`).
const mishnaHistoryLockRecheck = Duration(seconds: 30);

/// Whether the history must be unreadable now (AD-36): `AsyncData(true)`
/// while the target learner is inside a lock window.
///
/// The lock is the active learner's, not the device's: it reads that
/// learner's [learnerLockSettingsProvider] for the active
/// `LearnerScope` (in a tutored session, the talmid's scope) and asks the
/// shared [captureGateProvider] — the same judgement `LearningCommands`
/// applies to writes, so no second lock-window calculation exists. The
/// device lock ([currentSacredWindowProvider], the app-wide overlay) also
/// locks it. It fails closed: while the learner's settings load the value
/// is loading and the screen shows no event content; a read failure is an
/// error the screen offers to retry.
final mishnaHistoryLockProvider = Provider.autoDispose<AsyncValue<bool>>((ref) {
  if (ref.watch(currentSacredWindowProvider) != null) {
    return const AsyncData(true);
  }
  final scope = ref.watch(activeLearnerScopeProvider);
  if (scope case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<bool>(error, stackTrace);
  }
  if (!scope.hasValue) return const AsyncLoading<bool>();
  final active = scope.requireValue;
  // No learner: the history itself reports NoActiveLearnerException and
  // has no event content to hide.
  if (active == null) return const AsyncData(false);

  final settings = ref.watch(learnerLockSettingsProvider(active));
  if (settings case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<bool>(error, stackTrace);
  }
  if (!settings.hasValue) return const AsyncLoading<bool>();

  final timer = Timer(mishnaHistoryLockRecheck, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final decision = ref
      .watch(captureGateProvider)
      .check(settings.requireValue, DateTimeFactory.nowUtc());
  return AsyncData(decision is GateLocked);
});

/// Re-reads every input of the history (the AppErrorView retry). The
/// learner and leaf are unchanged: the screen keeps its arguments.
void retryMishnaHistory(WidgetRef ref) {
  ref
    ..invalidate(activeLearnerScopeProvider)
    ..invalidate(learnerLockSettingsProvider)
    ..invalidate(profileHistoryLogProvider)
    ..invalidate(learnerStateProvider)
    ..invalidate(corporaProvider);
}

/// A correction the user asked for.
sealed class MishnaCorrectionRequest {
  const MishnaCorrectionRequest();
}

/// Remove the row: `LearningCommands.voidEvent`.
final class RemoveEventRequest extends MishnaCorrectionRequest {
  /// Creates the request.
  const RemoveEventRequest();
}

/// Correct the row: `LearningCommands.replace`.
final class ReplaceEventRequest extends MishnaCorrectionRequest {
  /// Creates the request.
  const ReplaceEventRequest(this.replacement);

  /// The replacement fields (null keeps the target's value).
  final EventReplacement replacement;
}

/// How a correction ended.
enum MishnaCorrectionOutcome {
  /// The command succeeded and the server has it.
  applied,

  /// The command was accepted offline (`CaptureSuccess.queued`): the row
  /// stays pending until the history shows it, and a later server
  /// rejection rolls it back with feedback
  /// ([MishnaHistoryCorrectionsState.lateRollbacks]).
  queued,

  /// A child may not make this change (`CaptureResult.childLimit`).
  childLimit,

  /// The command refused or failed; the original row is restored.
  rolledBack,
}

/// The optimistic look of [item] once [request] is applied: a removal, or
/// a move to another leaf, shows as voided (hidden from a child); a date or
/// source change shows its new values. Display only: the stored event is
/// never edited (AD-31, AD-38).
MishnaHistoryItem optimisticItem(
  MishnaHistoryItem item,
  MishnaCorrectionRequest request,
) {
  final pending = item.copyWith(pending: true);
  if (request is! ReplaceEventRequest) {
    return pending.copyWith(status: MishnaHistoryStatus.voided);
  }
  final r = request.replacement;
  if (r.ref != null && r.ref != item.event.ref) {
    return pending.copyWith(status: MishnaHistoryStatus.voided);
  }
  final e = item.event;
  final dateState = r.dateState ?? e.dateState!;
  final source = r.source ?? e.source!;
  final shown = LearningEvent.learn(
    id: e.id,
    curriculumId: e.curriculumId!,
    ref: e.ref!,
    source: source,
    dateState: dateState,
    learnedOn: r.resolveLearnedOn(e.learnedOn),
    recordedAt: effectiveAt(e),
    actor: e.actor,
    level: e.level,
  );
  final toHome = source == LearningEvent.sourceMain;
  return pending.copyWith(
    event: shown,
    sourceKind: toHome ? MishnaHistorySourceKind.home : null,
  );
}

/// The optimistic overlays of one history and its late-rollback count.
final class MishnaHistoryCorrectionsState {
  /// Creates the state.
  const MishnaHistoryCorrectionsState({
    this.overlays = const {},
    this.lateRollbacks = 0,
  });

  /// Optimistic rows by event id.
  final Map<String, MishnaHistoryItem> overlays;

  /// How many queued corrections the server rejected after `correct`
  /// returned. Each increase is one rollback the screen announces with the
  /// rollback snackbar (UX-DR-142).
  final int lateRollbacks;

  /// A copy with the given fields replaced.
  MishnaHistoryCorrectionsState copyWith({
    Map<String, MishnaHistoryItem>? overlays,
    int? lateRollbacks,
  }) => MishnaHistoryCorrectionsState(
    overlays: overlays ?? this.overlays,
    lateRollbacks: lateRollbacks ?? this.lateRollbacks,
  );
}

/// Whether [history] shows the correction of [eventId]: a removal or a
/// replacement both void the target (AD-31), so the row is voided or gone.
bool _confirms(MishnaHistory history, String eventId) {
  for (final item in history.items) {
    if (item.eventId == eventId) {
      return item.status == MishnaHistoryStatus.voided;
    }
  }
  return true;
}

/// Optimistic overlays for one history, plus the correction commands.
///
/// An overlay lives until the refreshed history confirms its correction
/// (the target is voided or gone) — an unrelated history emission never
/// clears it. A queued (offline) correction is also tracked by the event
/// ids it wrote: if `LearningCommands.watchPendingFailures` later reports
/// one of them, the overlay is dropped (restoring the row the history
/// shows once the local write is reverted) and
/// [MishnaHistoryCorrectionsState.lateRollbacks] grows.
final class MishnaHistoryCorrections
    extends Notifier<MishnaHistoryCorrectionsState> {
  /// Creates the notifier for [args].
  MishnaHistoryCorrections(this.args);

  /// The history this notifier corrects.
  final MishnaHistoryArgs args;

  /// Targets whose command succeeded; their overlay waits for the history.
  final Set<String> _awaitingHistory = {};

  /// Queued corrections: target id → the event ids the write carries.
  final Map<String, Set<String>> _queued = {};

  StreamSubscription<List<PendingFailure>>? _failures;

  @override
  MishnaHistoryCorrectionsState build() {
    ref
      ..onDispose(() => unawaited(_failures?.cancel()))
      ..listen(mishnaHistoryProvider(args), (previous, next) {
        final history = next.value;
        if (history == null || _awaitingHistory.isEmpty) return;
        final confirmed = {
          for (final id in _awaitingHistory)
            if (_confirms(history, id)) id,
        };
        if (confirmed.isEmpty) return;
        _awaitingHistory.removeAll(confirmed);
        _dropOverlays(confirmed);
      });
    return const MishnaHistoryCorrectionsState();
  }

  void _dropOverlays(Set<String> ids) {
    if (!ids.any(state.overlays.containsKey)) return;
    state = state.copyWith(
      overlays: {
        for (final MapEntry(:key, :value) in state.overlays.entries)
          if (!ids.contains(key)) key: value,
      },
    );
  }

  void _watchFailures(LearningCommands commands) {
    _failures ??= commands.watchPendingFailures().listen(
      _onPendingFailures,
      onError: (Object _) {},
    );
  }

  void _onPendingFailures(List<PendingFailure> failures) {
    final failed = {for (final failure in failures) ...failure.eventIds};
    final rolledBack = {
      for (final MapEntry(:key, :value) in _queued.entries)
        if (value.any(failed.contains)) key,
    };
    if (rolledBack.isEmpty) return;
    for (final id in rolledBack) {
      _queued.remove(id);
    }
    _awaitingHistory.removeAll(rolledBack);
    _dropOverlays(rolledBack);
    state = state.copyWith(
      lateRollbacks: state.lateRollbacks + rolledBack.length,
    );
  }

  /// Applies [request] to [item] optimistically and runs the command.
  ///
  /// On any refusal or failure the overlay is removed — restoring the
  /// original row — before this future completes, so the caller's
  /// snackbar always follows the rollback. On success the overlay stays
  /// (pending) until the history confirms the correction.
  Future<MishnaCorrectionOutcome> correct(
    MishnaHistoryItem item,
    MishnaCorrectionRequest request,
  ) async {
    final id = item.eventId;
    state = state.copyWith(
      overlays: {...state.overlays, id: optimisticItem(item, request)},
    );
    CaptureResult result;
    LearningCommands? commands;
    try {
      commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) throw const NoActiveLearnerException();
      result = await switch (request) {
        RemoveEventRequest() => commands.voidEvent(id),
        ReplaceEventRequest(:final replacement) => commands.replace(
          id,
          replacement,
        ),
      };
    } on Object {
      result = const CaptureResult.rejected(CaptureRejection.invalid);
    }
    final outcome = switch (result) {
      CaptureSuccess(queued: true) => MishnaCorrectionOutcome.queued,
      CaptureSuccess() => MishnaCorrectionOutcome.applied,
      CaptureChildLimit() => MishnaCorrectionOutcome.childLimit,
      _ => MishnaCorrectionOutcome.rolledBack,
    };
    if (!ref.mounted) return outcome;
    if (result is! CaptureSuccess) {
      _dropOverlays({id});
      return outcome;
    }
    if (result.queued && commands != null) {
      _queued[id] = {...result.eventIds};
      _watchFailures(commands);
    }
    final history = ref.read(mishnaHistoryProvider(args)).value;
    if (history != null && _confirms(history, id)) {
      _dropOverlays({id});
    } else {
      _awaitingHistory.add(id);
    }
    return outcome;
  }
}

/// The corrections of one history.
final mishnaHistoryCorrectionsProvider = NotifierProvider.autoDispose
    .family<
      MishnaHistoryCorrections,
      MishnaHistoryCorrectionsState,
      MishnaHistoryArgs
    >(MishnaHistoryCorrections.new);

/// The history with its optimistic overlays applied — what the screen
/// renders.
final mishnaHistoryViewProvider = Provider.autoDispose
    .family<AsyncValue<MishnaHistory>, MishnaHistoryArgs>((ref, args) {
      final history = ref.watch(mishnaHistoryProvider(args));
      final overlays = ref.watch(
        mishnaHistoryCorrectionsProvider(args).select((s) => s.overlays),
      );
      return history.whenData((h) => h.withOverlays(overlays));
    });
