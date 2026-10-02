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
///   rollback snackbar (UX-DR-142).
///
/// Plain Riverpod providers (no codegen), matching the C0 provider style.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/profile_history_log_source.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
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

/// Re-reads every input of the history (the AppErrorView retry). The
/// learner and leaf are unchanged: the screen keeps its arguments.
void retryMishnaHistory(WidgetRef ref) {
  ref
    ..invalidate(activeLearnerScopeProvider)
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
  /// The command succeeded (or is queued offline).
  applied,

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
    learnedOn: dateState == DateState.beforeTracking
        ? null
        : r.learnedOn ?? e.learnedOn,
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

/// Optimistic overlays by event id for one history, plus the correction
/// commands.
final class MishnaHistoryCorrections
    extends Notifier<Map<String, MishnaHistoryItem>> {
  /// Creates the notifier for [args].
  MishnaHistoryCorrections(this.args);

  /// The history this notifier corrects.
  final MishnaHistoryArgs args;

  /// Overlays whose command succeeded; cleared when new history data lands.
  final Set<String> _confirmed = {};

  @override
  Map<String, MishnaHistoryItem> build() {
    ref.listen(mishnaHistoryProvider(args), (previous, next) {
      if (!next.hasValue || _confirmed.isEmpty) return;
      final done = {..._confirmed};
      _confirmed.clear();
      state = {
        for (final MapEntry(:key, :value) in state.entries)
          if (!done.contains(key)) key: value,
      };
    });
    return const {};
  }

  /// Applies [request] to [item] optimistically and runs the command.
  ///
  /// On any refusal or failure the overlay is removed — restoring the
  /// original row — before this future completes, so the caller's
  /// snackbar always follows the rollback.
  Future<MishnaCorrectionOutcome> correct(
    MishnaHistoryItem item,
    MishnaCorrectionRequest request,
  ) async {
    final id = item.eventId;
    final before = ref.read(mishnaHistoryProvider(args)).value;
    state = {...state, id: optimisticItem(item, request)};
    CaptureResult result;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
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
    if (!ref.mounted) {
      return result is CaptureSuccess
          ? MishnaCorrectionOutcome.applied
          : MishnaCorrectionOutcome.rolledBack;
    }
    if (result is CaptureSuccess) {
      // A local write usually lands before the command returns: if the
      // history already changed, drop the overlay now; otherwise when the
      // next history arrives.
      if (identical(ref.read(mishnaHistoryProvider(args)).value, before)) {
        _confirmed.add(id);
        return MishnaCorrectionOutcome.applied;
      }
    }
    state = {
      for (final MapEntry(:key, :value) in state.entries)
        if (key != id) key: value,
    };
    if (result is CaptureSuccess) return MishnaCorrectionOutcome.applied;
    return result is CaptureChildLimit
        ? MishnaCorrectionOutcome.childLimit
        : MishnaCorrectionOutcome.rolledBack;
  }
}

/// The corrections of one history.
final mishnaHistoryCorrectionsProvider = NotifierProvider.autoDispose
    .family<
      MishnaHistoryCorrections,
      Map<String, MishnaHistoryItem>,
      MishnaHistoryArgs
    >(MishnaHistoryCorrections.new);

/// The history with its optimistic overlays applied — what the screen
/// renders.
final mishnaHistoryViewProvider = Provider.autoDispose
    .family<AsyncValue<MishnaHistory>, MishnaHistoryArgs>((ref, args) {
      final history = ref.watch(mishnaHistoryProvider(args));
      final overlays = ref.watch(mishnaHistoryCorrectionsProvider(args));
      return history.whenData((h) => h.withOverlays(overlays));
    });
