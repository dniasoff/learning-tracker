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
// AUD-sync-01 fix (EH-5): SyncStatus.error no longer has a `message` field at
// all — it carries a stable [SyncErrorCode] enum. It is now structurally
// impossible for an exception's raw text to reach the code field; the only
// place e.toString() is retained is the non-user-facing `debugDetail` field.
//
// Test strategy:
//   Build a SyncOrchestratorImpl whose gateway's fetchPage() throws
//   FirestorePermissionDeniedException.  Call pullOnLaunch().  Assert:
//     1. The resulting SyncStatus.error.code is SyncErrorCode.permissionDenied
//        (a closed enum value — it cannot possibly contain a class name,
//        collection path, or SDK error code).
//     2. debugDetail (diagnostics-only) is non-empty but is a DIFFERENT
//        field from the one presentation is allowed to render.
//
// TimeoutException is also verified to classify as SyncErrorCode.timeout
// (pre-existing correct behavior).

@Tags(['unit', 'sync', 'sy3', 'vision-fix'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

// ── Helpers ───────────────────────────────────────────────────────────────────

SyncOrchestratorImpl _buildOrchestrator(FirestoreGateway gateway) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway,
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
  );
}

/// Runs [pullOnLaunch] on [orchestrator], collects status emissions, and
/// returns any [SyncStatusError] entries.
Future<List<SyncStatusError>> _collectErrors(
  SyncOrchestratorImpl orchestrator,
) async {
  final statuses = <SyncStatus>[];
  final sub = orchestrator.statusStream.listen(statuses.add);
  try {
    await orchestrator.pullOnLaunch();
  } catch (_) {
    // Expected: the orchestrator rethrows after emitting the error status.
  }
  // Yield one event-loop turn so any pending async status listeners settle.
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return statuses.whereType<SyncStatusError>().toList();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SY-3 / AUD-sync-01 — permission-denied classified, never leaked', () {
    test('pullOnLaunch emits SyncStatus.error with code permissionDenied, '
        'not the raw FirestorePermissionDeniedException.toString()', () async {
      final orchestrator = _buildOrchestrator(_PermissionDeniedGateway());
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      final errors = await _collectErrors(orchestrator);

      // There must be at least one error status.
      expect(
        errors,
        isNotEmpty,
        reason:
            'pullOnLaunch must emit SyncStatus.error when the gateway throws '
            'FirestorePermissionDeniedException',
      );

      final last = errors.last;

      // AUD-sync-01 assertion 1: the code is the closed enum value — by
      // construction it cannot contain a class name, collection path, or
      // SDK error code (unlike a free-text message ever could).
      expect(
        last.code,
        equals(SyncErrorCode.permissionDenied),
        reason:
            'SyncStatus.error.code must classify a Firestore permission-'
            'denied failure as SyncErrorCode.permissionDenied',
      );

      // AUD-sync-01 assertion 2: debugDetail is a SEPARATE, non-user-facing
      // field — presentation must never read it. It retains the raw text
      // for logs/diagnostics only.
      expect(
        last.debugDetail,
        contains('FirestorePermissionDeniedException'),
        reason:
            'debugDetail retains full diagnostic detail for logs — it is a '
            'different field from the presentation-facing code',
      );
    });

    test('TimeoutException classifies as SyncErrorCode.timeout '
        '(regression guard for pre-existing correct behavior)', () async {
      final orchestrator = _buildOrchestrator(_TimeoutGateway());
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      final errors = await _collectErrors(orchestrator);

      expect(
        errors,
        isNotEmpty,
        reason:
            'pullOnLaunch must emit SyncStatus.error when the gateway throws '
            'TimeoutException',
      );

      expect(
        errors.last.code,
        equals(SyncErrorCode.timeout),
        reason: 'TimeoutException must classify as SyncErrorCode.timeout',
      );
    });
  });
}
