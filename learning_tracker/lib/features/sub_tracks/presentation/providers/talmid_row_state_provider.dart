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
/// Lock (AD-36, product ruling 2026-10-05): the row follows the lock of
/// the person using the device ([currentSacredWindowProvider]), never the
/// talmid's own settings; while that lock is in force the row is
/// [TalmidRowLocked] (the overlay covers the app anyway).
///
/// Timeout (AD-54 Observability): a row still loading after
/// [talmidRowLoadTimeoutProvider] shows an inline retry on that row only
/// and reports one enum-only Crashlytics non-fatal
/// ([TalmidEngineLoadTimeoutError]); other rows are untouched.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/use_cases/build_talmid_row_state.dart';

/// Enables detailed, identity-bearing row diagnostics in internal builds.
const kInternalBuild = bool.fromEnvironment('INTERNAL_BUILD');

/// The talmid's engine state: the 4.2a grant-validated read path
/// ([learnerStateForScopeProvider]). The one seam tests replace.
final talmidLearnerStateProvider = Provider.autoDispose
    .family<AsyncValue<LearnerState>, LearnerScope>(
      (ref, scope) => ref.watch(learnerStateForScopeProvider(scope)),
    );

/// Whether the row must hide behind the lock now: the lock of the PERSON
/// USING THE DEVICE ([currentSacredWindowProvider], the tutor's own), never
/// the talmid's (product ruling 2026-10-05) — a talmid's Shabbos never
/// hides him from his tutor. Kept per row (and [scope]-keyed) so a row
/// retry re-reads it like every other row input.
final talmidLockProvider = Provider.autoDispose
    .family<AsyncValue<bool>, LearnerScope>(
      (ref, scope) => AsyncData(ref.watch(currentSacredWindowProvider) != null),
    );

/// How long a row may load before it shows its inline retry.
final talmidRowLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);

/// The `INTERNAL_BUILD` compile-time flag enables on-device row diagnostics.
final talmidRowInternalDiagnosticsEnabledProvider = Provider<bool>(
  (ref) => kInternalBuild,
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
  /// The device user's lock settings.
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
  Object? _lastLoggedError;

  @override
  bool build() => false;

  /// Whether [error] is a new instance for this row's current lifetime.
  bool shouldLog(Object error) {
    if (identical(_lastLoggedError, error)) return false;
    _lastLoggedError = error;
    return true;
  }

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
      void logOnce(String stage, Object error, StackTrace stackTrace) {
        if (!ref
            .read(talmidRowTimedOutProvider(scope).notifier)
            .shouldLog(error)) {
          return;
        }
        if (stage == TalmidRowFailure.accessEnded.name) {
          AppLogger.instance.info(
            event: 'talmid_row_load_failed',
            fields: {'stage': stage, 'errorType': error.runtimeType.toString()},
          );
        } else {
          _logTalmidRowError(stage, scope, error, stackTrace);
        }
      }

      final lock = ref.watch(talmidLockProvider(scope));
      final learner = ref.watch(talmidLearnerStateProvider(scope));
      final timedOut = ref.watch(talmidRowTimedOutProvider(scope));

      // Access ended outranks everything: the row leaves on the next
      // roster refresh and shows nothing of the learner meanwhile.
      if (learner case AsyncError(
        :final error,
        :final stackTrace,
      ) when error is TutorScopeAccessDeniedException) {
        logOnce(TalmidRowFailure.accessEnded.name, error, stackTrace);
        return TalmidRowFailed(
          TalmidRowFailure.accessEnded,
          diagnosticDetail: kInternalBuild
              ? _failureDetail(
                  scope: scope,
                  kind: TalmidRowFailure.accessEnded.name,
                  error: error,
                )
              : null,
        );
      }
      // Fail closed on the lock: no identity until it is known open.
      if (lock case AsyncData(value: true)) return const TalmidRowLocked();
      if (lock.hasError) {
        final failure = lock as AsyncError<bool>;
        logOnce('lock', failure.error, failure.stackTrace);
        return TalmidRowFailed(
          TalmidRowFailure.loadFailed,
          diagnosticDetail: kInternalBuild
              ? _failureDetail(
                  scope: scope,
                  kind: TalmidRowFailure.loadFailed.name,
                  error: failure.error,
                )
              : null,
        );
      }
      final lockOpen = lock is AsyncData<bool> && !lock.value;
      if (learner case AsyncError(:final error, :final stackTrace)) {
        logOnce('engine', error, stackTrace);
        return TalmidRowFailed(
          TalmidRowFailure.loadFailed,
          identityVisible: lockOpen,
          diagnosticDetail: kInternalBuild
              ? _failureDetail(
                  scope: scope,
                  kind: TalmidRowFailure.loadFailed.name,
                  error: error,
                )
              : null,
        );
      }
      if (lockOpen && learner.hasValue) {
        return buildTalmidRowState(learner.requireValue);
      }
      if (timedOut) {
        final stage = lockOpen ? TalmidLoadStage.engine : TalmidLoadStage.lock;
        final grant = kInternalBuild
            ? ref.watch(tutorScopeGrantProvider(scope))
            : null;
        final readiness = kInternalBuild
            ? ref.read(learnerStateInputReadinessProvider).pendingFor(scope)
            : const <String>[];
        return TalmidRowTimedOut(
          identityVisible: lockOpen,
          diagnosticDetail: kInternalBuild
              ? _timeoutDetail(
                  scope: scope,
                  stage: stage,
                  grantHasValue: grant?.hasValue ?? false,
                  pendingInputs: readiness,
                )
              : null,
        );
      }
      final timer = Timer(ref.watch(talmidRowLoadTimeoutProvider), () {
        if (!ref.mounted) return;
        final stage = lockOpen ? TalmidLoadStage.engine : TalmidLoadStage.lock;
        ref.read(talmidRowTimedOutProvider(scope).notifier).timedOut(stage);
      });
      ref.onDispose(timer.cancel);
      return lockOpen ? const TalmidRowLoading() : const TalmidRowPending();
    });

String _failureDetail({
  required LearnerScope scope,
  required String kind,
  required Object error,
}) {
  final errorSummary = '${error.runtimeType}: $error';
  final shortened = errorSummary.length <= 300
      ? errorSummary
      : '${errorSummary.substring(0, 297)}...';
  return 'Failure kind: $kind\n'
      'Scope: ownerUid=${scope.ownerUid}, profileId=${scope.profileId}\n'
      'Error: $shortened';
}

String _timeoutDetail({
  required LearnerScope scope,
  required TalmidLoadStage stage,
  required bool grantHasValue,
  required Iterable<String> pendingInputs,
}) {
  final pending = <String>[];
  if (stage == TalmidLoadStage.lock) {
    pending.add('device lock settings');
  } else {
    if (!grantHasValue) pending.add('grant');
    pending.addAll(pendingInputs);
    if (pending.isEmpty) {
      pending.add('learner-state composition');
    }
  }
  return 'Failure kind: timeout\n'
      'Scope: ownerUid=${scope.ownerUid}, profileId=${scope.profileId}\n'
      'Stage still pending: ${stage.name}\n'
      'Inputs without a value: ${pending.join(', ')}\n'
      'Error: none (load is still pending)';
}

void _logTalmidRowError(
  String stage,
  LearnerScope scope,
  Object error,
  StackTrace stackTrace,
) {
  logTalmidRowFailure(
    stage: stage,
    ownerUid: scope.ownerUid,
    profileId: scope.profileId,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Logs the complete failure through Talker and, for internal release builds,
/// writes it directly to logcat.
void logTalmidRowFailure({
  required String stage,
  required String ownerUid,
  required String profileId,
  required Object error,
  required StackTrace stackTrace,
}) {
  if (kInternalBuild) {
    AppLogger.instance.error(
      event: 'talmid_row_load_failed',
      fields: {'stage': stage, 'errorType': error.runtimeType.toString()},
      exception: error,
      stackTrace: stackTrace,
    );
    debugPrint(
      '[talmid_row_load_failed] stage=$stage '
      'ownerUid=$ownerUid profileId=$profileId\n'
      '$error\n$stackTrace',
    );
  } else {
    AppLogger.instance.error(
      event: 'talmid_row_load_failed',
      fields: {'stage': stage, 'errorType': error.runtimeType.toString()},
    );
  }
}
