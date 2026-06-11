// SY-3 regression test — Raw FirestorePermissionDeniedException must not
// leak verbatim into the SyncStatus.error message.
//
// Root cause (plan §ROOT sync ¶ SY-3):
//   sync_orchestrator.dart catches any non-Timeout exception and sets
//   `message = e.toString()`, which for FirestorePermissionDeniedException
//   produces the class name + internal collection + op + Firestore error code:
//     "FirestorePermissionDeniedException: ... (collection: completions),
//      op: read caused by: [cloud_firestore/permission-denied]"
//   That raw string is fed into the `backupSyncError(message)` ARB template
//   and rendered verbatim in the Backup & Sync card — exposing internal
//   collection names, class names, and Firestore error codes to end users.
//
// Fix: map FirestorePermissionDeniedException to a friendly message in
// sync_orchestrator.dart instead of calling e.toString().
//
// Test strategy:
//   Build a SyncOrchestratorImpl whose gateway's fetchPage() throws
//   FirestorePermissionDeniedException.  Call pullOnLaunch().  Assert:
//     1. The resulting SyncStatus.error.message does NOT contain the raw
//        exception class name ("FirestorePermissionDeniedException").
//     2. The message does NOT contain "collection:" or "op:" (internal labels).
//     3. The message does NOT contain "[cloud_firestore/permission-denied]".
//     4. The message is a non-empty, user-facing string.
//
// TimeoutException messages are also verified to remain friendly (pre-existing
// correct behavior).

@Tags(['unit', 'sync', 'sy3', 'vision-fix'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
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

  group('SY-3 — FirestorePermissionDeniedException sanitized in error status', () {
    test('pullOnLaunch emits SyncStatus.error with a friendly message, '
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

      final errorMessage = errors.last.message;

      // SY-3 assertion 1: class name must not leak.
      expect(
        errorMessage.contains('FirestorePermissionDeniedException'),
        isFalse,
        reason:
            'SyncStatus.error.message must not expose the raw exception class name '
            '— users must see a friendly message, not "FirestorePermissionDeniedException: ..."',
      );

      // SY-3 assertion 2: internal "collection:" label must not leak.
      expect(
        errorMessage.contains('collection:'),
        isFalse,
        reason:
            'SyncStatus.error.message must not expose internal Firestore '
            'collection path labels',
      );

      // SY-3 assertion 3: raw Firestore error code must not leak.
      expect(
        errorMessage.contains('[cloud_firestore/permission-denied]'),
        isFalse,
        reason:
            'SyncStatus.error.message must not expose raw Firestore SDK '
            'error codes visible only to developers',
      );

      // SY-3 assertion 4: message must be non-empty and user-facing.
      expect(
        errorMessage,
        isNotEmpty,
        reason: 'SyncStatus.error.message must be non-empty',
      );
      expect(
        errorMessage.length,
        greaterThan(10),
        reason:
            'A friendly user-facing error message must have meaningful content',
      );
    });

    test('TimeoutException still maps to friendly "timed out" message '
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

      final msg = errors.last.message;

      // The Timeout message must remain friendly (pre-existing behavior).
      expect(
        msg,
        contains('timed out'),
        reason:
            'TimeoutException must still produce a "Sync timed out" message',
      );
      expect(
        msg.contains('TimeoutException'),
        isFalse,
        reason:
            'TimeoutException class name must not appear in the user-facing message',
      );
    });
  });
}
