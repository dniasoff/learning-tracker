/// Per-talmid row evaluation for My talmidim (Story 4.3, DNI-511, T2;
/// FR-29, AD-35, AD-36, AD-54).
///
/// [talmidRowStateProvider] is an `autoDispose` family keyed by the
/// talmid's [LearnerScope], watched by the row widget only. A lazy list
/// builds only rows on screen or inside its cache extent, so the engine
/// runs one learner at a time for visible and about-to-scroll rows, and
/// each row's [LearnerState] stays warm in memory while the row is built
/// (AD-35 "Tutor list"; 4.2a [learnerStateForScopeProvider]).
///
/// Lock privacy (AD-36): the row judges the TALMID's own settings history
/// with the shared [captureGateProvider]. Until his lock is known to be
/// open the row carries no identity or data ([TalmidRowPending]); while
/// locked it is [TalmidRowLocked]. Nothing here feeds the tutor device's
/// own `SacredTimeLockOverlay`, which stays driven by the account's own
/// profiles.
///
/// Timeout (AD-54 Observability): a row still loading after
/// [talmidRowLoadTimeoutProvider] shows an inline retry on that row only
/// and reports one enum-only Crashlytics non-fatal
/// ([TalmidEngineLoadTimeoutError]); other rows are untouched.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/use_cases/build_talmid_row_state.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show tutoredLearnerLockRecheckDelay;

/// The talmid's engine state: the 4.2a grant-validated read path
/// ([learnerStateForScopeProvider]). The one seam tests replace.
final talmidLearnerStateProvider = Provider.autoDispose
    .family<AsyncValue<LearnerState>, LearnerScope>(
      (ref, scope) => ref.watch(learnerStateForScopeProvider(scope)),
    );

/// Whether the TALMID is inside a lock window now, judged on his own
/// settings history (AD-36); loading while it loads. Re-judged at the next
/// lock boundary.
final talmidLockProvider = Provider.autoDispose
    .family<AsyncValue<bool>, LearnerScope>((ref, scope) {
      final settings = ref.watch(learnerLockSettingsProvider(scope));
      if (settings case AsyncError(:final error, :final stackTrace)) {
        return AsyncError<bool>(error, stackTrace);
      }
      if (!settings.hasValue) return const AsyncLoading<bool>();
      final history = settings.requireValue;
      final now = ref.watch(learningCommandClockProvider)().toUtc();
      final decision = ref.watch(captureGateProvider).check(history, now);
      final timer = Timer(
        tutoredLearnerLockRecheckDelay(history, now, decision),
        ref.invalidateSelf,
      );
      ref.onDispose(timer.cancel);
      return AsyncData(decision is GateLocked);
    });

/// How long a row may load before it shows its inline retry.
final talmidRowLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);

/// The AD-54 engine load-timeout diagnostic: enums only — no learner id,
/// name, ref or event data.
final class TalmidEngineLoadTimeoutError implements Exception {
  /// Creates the error.
  const TalmidEngineLoadTimeoutError({required this.stage});

  /// What was still loading when the row timed out.
  final TalmidLoadStage stage;

  @override
  String toString() => 'TalmidEngineLoadTimeout(stage: ${stage.name})';
}

/// The input a timed-out row was still waiting for.
enum TalmidLoadStage {
  /// The talmid's lock settings.
  lock,

  /// The talmid's engine state.
  engine,
}

/// Reports a row's load timeout.
abstract interface class TalmidRowDiagnostics {
  /// A row timed out while [stage] was loading.
  void engineLoadTimedOut(TalmidLoadStage stage);
}

final class _CrashlyticsTalmidRowDiagnostics implements TalmidRowDiagnostics {
  const _CrashlyticsTalmidRowDiagnostics(this._crashlytics);

  final CrashlyticsService _crashlytics;

  @override
  void engineLoadTimedOut(TalmidLoadStage stage) {
    unawaited(
      _crashlytics
          .recordError(
            TalmidEngineLoadTimeoutError(stage: stage),
            StackTrace.current,
          )
          .catchError((Object _) {}),
    );
  }
}

/// The diagnostics sink: a Crashlytics non-fatal.
final talmidRowDiagnosticsProvider = Provider<TalmidRowDiagnostics>(
  (ref) =>
      _CrashlyticsTalmidRowDiagnostics(ref.watch(crashlyticsServiceProvider)),
);

/// Whether the row of a scope has timed out ([TalmidRowLoad.retry] clears
/// it).
final talmidRowTimedOutProvider = NotifierProvider.autoDispose
    .family<TalmidRowLoad, bool, LearnerScope>(TalmidRowLoad.new);

/// The load bookkeeping of one row: its timed-out flag and its retry.
class TalmidRowLoad extends Notifier<bool> {
  /// Creates the bookkeeping for [scope].
  TalmidRowLoad(this.scope);

  /// The row's scope.
  final LearnerScope scope;

  @override
  bool build() => false;

  /// The row's load ran out of time while [stage] was loading.
  void timedOut(TalmidLoadStage stage) {
    if (state) return;
    state = true;
    ref.read(talmidRowDiagnosticsProvider).engineLoadTimedOut(stage);
  }

  /// Re-reads this row's inputs after a timeout or a failed load; other
  /// rows are untouched.
  void retry() {
    state = false;
    ref
      ..invalidate(tutorScopeGrantProvider(scope))
      ..invalidate(learnerStateProvider(scope))
      ..invalidate(learnerLockSettingsProvider(scope))
      ..invalidate(talmidLearnerStateProvider(scope))
      ..invalidate(talmidLockProvider(scope));
  }
}

/// The row of the talmid at [scope].
final talmidRowStateProvider = Provider.autoDispose
    .family<TalmidRowState, LearnerScope>((ref, scope) {
      final lock = ref.watch(talmidLockProvider(scope));
      final learner = ref.watch(talmidLearnerStateProvider(scope));
      final timedOut = ref.watch(talmidRowTimedOutProvider(scope));

      // Access ended outranks everything: the row leaves on the next
      // roster refresh and shows nothing of the learner meanwhile.
      if (learner case AsyncError(error: TutorScopeAccessDeniedException())) {
        return const TalmidRowFailed(TalmidRowFailure.accessEnded);
      }
      // Fail closed on the lock: no identity until it is known open.
      if (lock case AsyncData(value: true)) return const TalmidRowLocked();
      if (lock.hasError) {
        return const TalmidRowFailed(TalmidRowFailure.loadFailed);
      }
      final lockOpen = lock is AsyncData<bool> && !lock.value;
      if (learner case AsyncError()) {
        return TalmidRowFailed(
          TalmidRowFailure.loadFailed,
          identityVisible: lockOpen,
        );
      }
      if (lockOpen && learner.hasValue) {
        return buildTalmidRowState(learner.requireValue);
      }
      if (timedOut) return TalmidRowTimedOut(identityVisible: lockOpen);
      final timer = Timer(
        ref.watch(talmidRowLoadTimeoutProvider),
        () => ref
            .read(talmidRowTimedOutProvider(scope).notifier)
            .timedOut(lockOpen ? TalmidLoadStage.engine : TalmidLoadStage.lock),
      );
      ref.onDispose(timer.cancel);
      return lockOpen ? const TalmidRowLoading() : const TalmidRowPending();
    });
