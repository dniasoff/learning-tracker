// SY-3 / AUD-sync-01 (EH-5) regression test — a Firestore permission-denied
// failure must never leak verbatim into a user-facing string.
//
// Root cause (plan §ROOT sync ¶ SY-3, superseded by AUD-sync-01):
//   sync_orchestrator.dart used to catch any non-Timeout exception and set
//   `message = e.toString()`, which for FirestorePermissionDeniedException
//   produced the class name + internal collection + op + Firestore error code:
//     "FirestorePermissionDeniedException: ... (collection: completions),
//      op: read caused by: [cloud_firestore/permission-denied]"
//   That raw string was fed into an ARB template and rendered verbatim in the
//   Backup & Sync card — exposing internal collection names, class names, and
//   Firestore error codes to end users.
//
// AUD-sync-01 fix (EH-5): the classification into a stable [SyncErrorCode]
// enum (never a raw message) is preserved. Story 1.5 / AD-11 goes further:
// `SyncStatus` no longer has an `error` case AT ALL — the classified code
// and the raw `debugDetail` are forwarded straight to telemetry
// (Crashlytics + structured logs) at the pullOnLaunch catch site instead of
// living on the status union. It is now structurally impossible for the
// classified code — or any raw exception text — to reach the ambient
// SyncStatus the UI renders: the union only ever carries `localOnly` /
// `syncing(startedAt)` / `synced(lastSyncedAt)` / `offline()`, none of which
// have a string/message field at all.
//
// Test strategy:
//   Build a SyncOrchestratorImpl whose gateway's fetchPage() throws
//   FirestorePermissionDeniedException. Call pullOnLaunch(). Assert:
//     1. The emitted SyncStatus is `syncing` (online, unsettled) — never a
//        lie, and structurally incapable of carrying the raw exception text.
//     2. The classification still happens and reaches telemetry: the
//        Crashlytics spy records the stable SyncErrorCode.permissionDenied
//        AND the raw debugDetail (diagnostics-only, never rendered to a
//        user — there is no UI surface that could render it even if it
//        wanted to).
//
// TimeoutException is also verified to classify as SyncErrorCode.timeout
// (pre-existing correct behavior).

@Tags(['unit', 'sync', 'sy3', 'vision-fix'])
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show FlutterErrorDetails;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// A gateway that throws [FirestorePermissionDeniedException] on [fetchPage]
/// — the one-shot read path used by PullPipeline inside pullOnLaunch().
/// This simulates PERMISSION_DENIED on the `completions` collection, which is
/// the exact scenario from the audit report.
///
/// All listener paths (listenToCollection etc.) return empty streams so that
/// ListenerSupervisor.start() initialises without error; only the pull path
/// throws.
class _PermissionDeniedGateway implements FirestoreGateway {
  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    throw FirestorePermissionDeniedException(
      'PERMISSION_DENIED: Missing or insufficient permissions.',
      collection: collection,
      operation: 'read',
      cause: '[cloud_firestore/permission-denied] ...',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Gateway that throws TimeoutException on fetchPage (simulates network
/// timeout during the PullPipeline one-shot read inside pullOnLaunch()).
class _TimeoutGateway implements FirestoreGateway {
  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    throw TimeoutException('sync_pull_step_timeout: completions');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures every `recordError` call for assertion (mirrors the spy in
/// sync_orchestrator_test.dart).
class _RecordedCrashError {
  const _RecordedCrashError(this.error, this.fatal);
  final Object error;
  final bool fatal;
}

class _SpyCrashlyticsService implements CrashlyticsService {
  final List<_RecordedCrashError> recorded = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    recorded.add(_RecordedCrashError(error, fatal));
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserIdentifier(int? profileId) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

SyncOrchestratorImpl _buildOrchestrator(
  FirestoreGateway gateway, {
  CrashlyticsService? crashlytics,
}) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway,
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    crashlytics: crashlytics,
  );
}

/// Runs [pullOnLaunch] on [orchestrator] and collects every emitted status.
Future<List<SyncStatus>> _runPull(SyncOrchestratorImpl orchestrator) async {
  final statuses = <SyncStatus>[];
  final sub = orchestrator.statusStream.listen(statuses.add);
  try {
    await orchestrator.pullOnLaunch();
  } catch (_) {
    // Expected: the orchestrator rethrows after emitting the collapsed status.
  }
  // Yield one event-loop turn so any pending async status listeners settle.
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return statuses;
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SY-3 / AUD-sync-01 — permission-denied classified, never leaked', () {
    test(
      'pullOnLaunch emits SyncStatus.syncing (never the raw '
      'FirestorePermissionDeniedException.toString(), never a terminal lie)',
      () async {
        final spy = _SpyCrashlyticsService();
        final orchestrator = _buildOrchestrator(
          _PermissionDeniedGateway(),
          crashlytics: spy,
        );
        addTearDown(orchestrator.dispose);
        orchestrator.start();

        final statuses = await _runPull(orchestrator);

        // The ambient status is `syncing` — structurally incapable of
        // carrying the raw exception text (the case has only a
        // `startedAt: DateTime` field).
        expect(
          statuses,
          isNotEmpty,
          reason: 'pullOnLaunch must emit a status even on failure',
        );
        expect(statuses.last, isA<SyncStatusSyncing>());

        // The classification still reaches telemetry (diagnostics-only).
        expect(spy.recorded, isNotEmpty);
        final text = spy.recorded.last.error.toString();
        expect(
          text,
          contains(SyncErrorCode.permissionDenied.name),
          reason:
              'the stable code must classify a Firestore permission-denied '
              'failure',
        );
        expect(
          text,
          contains('FirestorePermissionDeniedException'),
          reason:
              'debugDetail retains full diagnostic detail for logs — this '
              'is a Crashlytics-only, non-user-facing surface',
        );
      },
    );

    test('TimeoutException classifies as SyncErrorCode.timeout '
        '(regression guard for pre-existing correct behavior)', () async {
      final spy = _SpyCrashlyticsService();
      final orchestrator = _buildOrchestrator(
        _TimeoutGateway(),
        crashlytics: spy,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      final statuses = await _runPull(orchestrator);

      expect(statuses, isNotEmpty);
      expect(statuses.last, isA<SyncStatusSyncing>());
      expect(spy.recorded, isNotEmpty);
      expect(
        spy.recorded.last.error.toString(),
        contains(SyncErrorCode.timeout.name),
        reason: 'TimeoutException must classify as SyncErrorCode.timeout',
      );
    });
  });
}
