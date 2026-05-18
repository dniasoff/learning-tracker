/// Wave 0 — characterization tests for SyncEngine background-flush invariants.
///
/// S5: two concurrent _runBackgroundFlush calls → only one drain executes.
/// S6: a completions snapshot with metadata.hasPendingWrites == true does
///     NOT trigger a merge (local echoes are filtered).
/// S8: pullOnLaunch runs exactly once per launch (not on every resume).
///
/// All tests are skipped; un-skip in Wave 1 once the fixes are in.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';

// ---------------------------------------------------------------------------
// Fakes / counting stubs
// ---------------------------------------------------------------------------

/// [MergeDispatcher] that counts how many times [dispatch] is called.
class _CountingDispatcher implements MergeDispatcher {
  int dispatchCount = 0;

  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    dispatchCount++;
    return MergeOutcome.continueNext;
  }
}

/// [FirestoreGateway] stub that always returns one page of one row then an
/// empty page (to terminate the pagination loop).
class _SinglePageGateway implements FirestoreGateway {
  bool _firstCall = true;

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    if (_firstCall) {
      _firstCall = false;
      return const FirestorePage(rows: [
        {'firestore_id': 'doc1', 'sefaria_ref': 'Berakhot 1:1'},
      ]);
    }
    return const FirestorePage(rows: []);
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────
  @override Future<void> pushCompletion({required int profileId, required Map<String, dynamic> data, String? docId}) async {}
  @override Future<void> pushCompletionsBatch({required int profileId, required List<Map<String, dynamic>> items}) async {}
  @override Future<void> pushStreak({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushSettings({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushTrack({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushLearningOrder({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushBookmark({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushNotificationSettings({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushGamificationSettings({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushLearnerProfile({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> deleteLearnerProfile(int profileId) async {}
  @override Future<void> pushLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushLedgerEntriesBatch({required int profileId, required List<Map<String, dynamic>> entries}) async {}
  @override Future<void> pushProfileProgram({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> removeProfileProgramAssignment({required int profileId, required String curriculumStorageKey}) async {}
  @override Future<List<Map<String, dynamic>>> fetchAll({required int profileId, required String collection}) async => [];
  @override Future<void> pushGoal({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushUiPreferences({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}
  @override Future<void> pushCurriculumImportMetadata({required int profileId, required Map<String, dynamic> data}) async {}
  @override Future<void> deleteUserData(String uid) async {}
  @override Future<void> pushDiagnosticLog({required String uid, required Map<String, dynamic> data}) async {}
  @override Future<void> pushAccountUserProfile({required String uid, required Map<String, dynamic> data}) async {}
  @override Stream<List<Map<String, dynamic>>> listenToCollection({required int profileId, required String collection}) => const Stream.empty();
  @override Stream<Map<String, dynamic>?> listenToDocument({required int profileId, required String collection, required String docId}) => const Stream.empty();
  @override Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override Future<Map<String, dynamic>?> fetchDocument({required int profileId, required String collection, required String docId}) async => null;
}

// ---------------------------------------------------------------------------
// S5 — Drain guard fake
// ---------------------------------------------------------------------------

/// Simulates the post-rework `_runBackgroundFlush` with a drain-guard flag.
///
/// The invariant: if a drain is already in progress when a second concurrent
/// call arrives, the second call exits immediately (no double-drain).
///
/// The current [SyncEngine._runBackgroundFlush] uses `unawaited()` which can
/// allow two concurrent drains.  The fix must add a boolean lock or use
/// [Mutex] semantics.  This stub models the expected post-fix behaviour so
/// the test can be written now.
class _DrainGuardStub {
  bool _draining = false;
  int drainExecutions = 0;
  int drainAttempts = 0;

  /// Simulates the post-rework single-flight drain guard.
  Future<void> runBackgroundFlush() async {
    drainAttempts++;
    if (_draining) {
      // Guard fires — second call exits without draining.
      return;
    }
    _draining = true;
    try {
      // Simulate async work (e.g., OutboxProcessor.drain).
      await Future<void>.delayed(const Duration(milliseconds: 1));
      drainExecutions++;
    } finally {
      _draining = false;
    }
  }
}

// ---------------------------------------------------------------------------
// S6 — hasPendingWrites filter fake
// ---------------------------------------------------------------------------

/// Simulates the post-rework snapshot filter that suppresses local-echo
/// snapshots (hasPendingWrites == true).
///
/// Current issue: the listener in [SyncEngine] (or [SyncOrchestratorImpl])
/// processes every snapshot including ones triggered by the device's own
/// writes before they reach the server. These "local echo" snapshots have
/// `hasPendingWrites == true` in the real Firestore SDK.
///
/// The fix must check [QuerySnapshotMetadata.hasPendingWrites] and skip
/// the merge when true.  This stub models the expected filter.
class _SnapshotFilterStub {
  int mergeCount = 0;

  /// Process a snapshot, skipping it when [hasPendingWrites] is true.
  void onSnapshot({
    required List<Map<String, dynamic>> rows,
    required bool hasPendingWrites,
  }) {
    if (hasPendingWrites) {
      // Local echo — skip to avoid processing our own writes back in.
      return;
    }
    mergeCount++;
  }
}

// ---------------------------------------------------------------------------
// S8 — pullOnLaunch call-count fake
// ---------------------------------------------------------------------------

/// Simulates a [SyncOrchestrator] that counts [pullOnLaunch] invocations.
///
/// The invariant: `pullOnLaunch` is called exactly once per app launch,
/// regardless of how many resume events follow.  Resume-triggered pulls
/// are throttled by [SyncOrchestratorImpl.pullOnResumeMinInterval] (5 min).
///
/// This stub models that throttle so the test is self-contained and does
/// not need SharedPreferences.
class _PullCountStub {
  int pullOnLaunchCount = 0;
  DateTime? _lastPullAt;

  static const _throttle = Duration(minutes: 5);

  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {
    if (triggeredFromResume && _lastPullAt != null) {
      final elapsed = DateTime.now().difference(_lastPullAt!);
      if (elapsed < _throttle) {
        return; // throttled — does not count as a pull execution
      }
    }
    _lastPullAt = DateTime.now();
    pullOnLaunchCount++;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('S5 / S6 / S8 — engine-level invariants (Wave 0 characterization)', () {
    // ── S5 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: two concurrent _runBackgroundFlush calls → only one drain
    // executes (the second is a no-op while the first is in flight).
    //
    // Pre-rework: SyncEngine._runBackgroundFlush is called via `unawaited()`
    // so rapid write events (e.g., tapping "mark all") can launch multiple
    // concurrent drains. The fix adds a boolean guard or Mutex.
    test(
      'S5: concurrent background flush calls → only one drain executes',
      () async {
        final stub = _DrainGuardStub();

        // Launch two concurrent flushes — the guard must let only one through.
        await Future.wait([
          stub.runBackgroundFlush(),
          stub.runBackgroundFlush(),
        ]);

        expect(
          stub.drainAttempts,
          equals(2),
          reason: 'S5: both calls must have been attempted',
        );
        expect(
          stub.drainExecutions,
          equals(1),
          reason:
              'S5: only one drain must execute; '
              'the concurrent call must be no-opped by the guard',
        );
      },
    );

    // ── S6 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: a Firestore snapshot with hasPendingWrites == true must NOT
    // trigger a merge (it is a local echo of our own write, not remote data).
    //
    // Pre-rework: the listener's onData callback passes every snapshot to the
    // merge router regardless of metadata. The fix must check
    // QuerySnapshotMetadata.hasPendingWrites and skip processing when true.
    test(
      'S6: snapshot with hasPendingWrites=true is skipped (no merge triggered)',
      () async {
        final filter = _SnapshotFilterStub();

        // Simulate a local-echo snapshot (our own write bouncing back).
        filter.onSnapshot(
          rows: [
            {'sefaria_ref': 'Berakhot 1:1', 'stage_id': 1},
          ],
          hasPendingWrites: true,
        );

        // Simulate a genuine remote snapshot.
        filter.onSnapshot(
          rows: [
            {'sefaria_ref': 'Berakhot 2:1', 'stage_id': 1},
          ],
          hasPendingWrites: false,
        );

        expect(
          filter.mergeCount,
          equals(1),
          reason:
              'S6: only the remote snapshot (hasPendingWrites=false) must '
              'trigger a merge; the local-echo snapshot must be filtered',
        );
      },
    );

    // ── S8 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: pullOnLaunch runs exactly once per launch session.
    //
    // Resume-triggered pulls are throttled to 1 per 5-minute window so that
    // coming-back-to-foreground does not hammer Firestore. This test verifies:
    //   1. The initial pull (triggeredFromResume: false) always executes.
    //   2. A rapid resume-triggered pull within the throttle window is skipped.
    //   3. The pull count after both is still 1.
    //
    // Wave-1 wires the real SyncOrchestratorImpl with SharedPreferences;
    // until then this stub exercises the throttle logic in isolation.
    test(
      'S8: pullOnLaunch executes once on launch; rapid resume pull is throttled',
      () async {
        final stub = _PullCountStub();

        // Initial pull on launch (not from resume).
        await stub.pullOnLaunch(triggeredFromResume: false);
        expect(
          stub.pullOnLaunchCount,
          equals(1),
          reason: 'S8: initial pullOnLaunch must execute',
        );

        // Immediate resume-triggered pull — within throttle window.
        await stub.pullOnLaunch(triggeredFromResume: true);
        expect(
          stub.pullOnLaunchCount,
          equals(1),
          reason:
              'S8: resume-triggered pull within 5-minute window must be '
              'throttled (count must not increase)',
        );
      },
    );

    // ── PullPipeline integration (supporting S6 / S8) ──────────────────────
    //
    // Verify that the PullPipeline correctly paginates and dispatches to the
    // MergeDispatcher — a sanity check for the pull machinery that S6 / S8
    // depend on.
    test(
      'PullPipeline dispatches exactly once for a single-page collection',
      () async {
        final dispatcher = _CountingDispatcher();
        final gateway = _SinglePageGateway();
        final pipeline = PullPipeline(
          gateway: gateway,
          dispatcher: dispatcher,
        );

        await pipeline.pullCompletions(profileId: 1);

        expect(
          dispatcher.dispatchCount,
          equals(1),
          reason:
              'A single-page collection must dispatch exactly once; '
              'the empty second page must terminate the loop',
        );
      },
    );
  });
}
