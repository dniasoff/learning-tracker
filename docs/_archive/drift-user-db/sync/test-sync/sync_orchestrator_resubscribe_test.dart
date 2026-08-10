/// Story 1.3 (FR15/AD-9/R-1/R-8): tests for [SyncOrchestratorImpl]'s
/// dead-channel resubscribe wiring — connectivity-online and lifecycle-resume
/// both trigger a resubscribe of every dead channel (own AND tutored) via the
/// Story 1.1/1.2 machinery, coalesced under flapping, and leaving a healthy
/// fleet untouched.
///
/// Includes red-demo (a) from the story brief: a dead channel + connectivity-
/// online must resubscribe — before Story 1.3's `_resubscribeDeadChannels`
/// wiring, connectivity-online only reset the Firestore network (which does
/// NOT resurrect an already-terminated `.snapshots()` stream) and drained the
/// outbox; the dead channel stayed dark. Red-demo (b) — a resume preceded
/// only by an `inactive` blip must NOT trigger a full network reset — lives
/// in `test/sync/lifecycle_observer_test.dart` (the observer, not the
/// orchestrator, owns that gate).
///
/// Error injection deliberately mirrors Story 1.2's
/// `_RecorderChildGateway.errorAndTerminateCollection` pattern (see
/// `tutored_listener_supervisor_test.dart`): every `listenToCollection` /
/// `listenToChildCollection` call opens a BRAND NEW broadcast controller for
/// that generation, and the error helper both `addError`s AND `close`s the
/// CURRENT generation's controller — a bare `addError` on an unclosed
/// broadcast controller would NOT faithfully model Firestore's
/// terminal-on-error `.snapshots()` contract and would let a stale
/// subscription "recover" without a genuine resubscribe, the exact vacuous-
/// test trap the story brief warns about.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart'
    show MergeDispatcher, MergeOutcome;
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/sync/tutored_listener_supervisor.dart';

// ---------------------------------------------------------------------------
// Own-account gateway fake: generation-tracked per collection, exactly like
// Story 1.2's `_RecorderChildGateway` but for `listenToCollection` /
// `listenToDocument` (the own-account gateway surface).
// ---------------------------------------------------------------------------

class _RecorderGateway implements FirestoreGateway {
  final Map<String, List<StreamController<Object?>>> _collectionGenerations =
      {};

  /// Total `listenToCollection` calls per collection — the "open count".
  final Map<String, int> openCounts = {};

  StreamController<Object?> _newGeneration(String collection) {
    openCounts.update(collection, (v) => v + 1, ifAbsent: () => 1);
    final ctrl = StreamController<Object?>.broadcast();
    _collectionGenerations.putIfAbsent(collection, () => []).add(ctrl);
    return ctrl;
  }

  StreamController<Object?> latest(String collection) =>
      _collectionGenerations[collection]!.last;

  /// Deliver a terminal error on [collection]'s CURRENT generation, then
  /// close it — faithfully models Firestore's terminal-on-error contract
  /// (see the class doc comment above for why this matters).
  void errorAndTerminateCollection(String collection, Object error) {
    final controller = latest(collection);
    controller.addError(error, StackTrace.current);
    unawaited(controller.close());
  }

  void emit(String collection, List<Map<String, dynamic>> rows) {
    latest(collection).add(ListenerSnapshot(rows: rows, isAtLimit: false));
  }

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => _newGeneration(collection).stream.cast<ListenerSnapshot>();

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tutored gateway fake — mirrors Story 1.2's `_RecorderChildGateway`.
// ---------------------------------------------------------------------------

class _RecorderChildGateway implements FirestoreGateway {
  final Map<String, List<StreamController<Object?>>> _collectionGenerations =
      {};
  final Map<String, int> openCounts = {};

  StreamController<Object?> _newGeneration(String collection) {
    openCounts.update(collection, (v) => v + 1, ifAbsent: () => 1);
    final ctrl = StreamController<Object?>.broadcast();
    _collectionGenerations.putIfAbsent(collection, () => []).add(ctrl);
    return ctrl;
  }

  StreamController<Object?> latest(String collection) =>
      _collectionGenerations[collection]!.last;

  void errorAndTerminateCollection(String collection, Object error) {
    final controller = latest(collection);
    controller.addError(error, StackTrace.current);
    unawaited(controller.close());
  }

  @override
  Stream<ListenerSnapshot> listenToChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => _newGeneration(collection).stream.cast<ListenerSnapshot>();

  @override
  Stream<Map<String, dynamic>?> listenToChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => throw StateError('own-data method must not be called');

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      throw StateError('own-data method must not be called');

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      throw StateError('own-data method must not be called');

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => throw StateError('own-data method must not be called');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('${invocation.memberName} must not be called');
}

class _NoopDispatcher implements MergeDispatcher {
  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async => MergeOutcome.continueNext;
}

// A huge backoff so the channel's OWN Story-1.1 automatic resubscribe timer
// definitely does not fire inside this test's short (~2s) assertion window —
// isolating the signal to Story 1.3's explicit connectivity/resume trigger.
const _hugeBackoff = Duration(minutes: 5);

SyncOrchestratorImpl _buildOrchestrator({
  required FirestoreGateway gateway,
  Stream<bool>? connectivityStream,
  TutoredListenerSupervisor? Function()? resolveTutoredListenerSupervisor,
}) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway,
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    connectivityStream: connectivityStream,
    resetFirestoreNetworkOverride: () async {},
    resolveTutoredListenerSupervisor: resolveTutoredListenerSupervisor,
    resubscribeBackoffBase: _hugeBackoff,
    resubscribeBackoffCap: _hugeBackoff,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story 1.3 — connectivity-online resubscribes dead channels', () {
    test(
      'RED-DEMO (a): a dead channel + connectivity-online resubscribes it '
      '(own fleet) — pre-Story-1.3 this channel stays dark forever',
      () async {
        final gateway = _RecorderGateway();
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          gateway: gateway,
          connectivityStream: controller.stream,
        );
        addTearDown(orchestrator.dispose);

        orchestrator.start();
        await Future<void>.delayed(Duration.zero);
        expect(gateway.openCounts['completions'], 1);

        // Kill the completions channel — a genuine terminal error, exactly
        // like a permission-denied / App-Check failure mid-session. With the
        // huge injected backoff, Story 1.1's own automatic resubscribe will
        // NOT fire inside this test.
        gateway.errorAndTerminateCollection(
          'completions',
          Exception('permission-denied (test)'),
        );
        await Future<void>.delayed(Duration.zero);

        // Seed offline, then transition online — mirrors the existing
        // connectivity-reset test's own timing (1.5 s debounce).
        controller.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        controller.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 1700));

        expect(
          gateway.openCounts['completions'],
          greaterThanOrEqualTo(2),
          reason:
              'connectivity-online must resubscribe the dead channel — a '
              'fresh listenToCollection call for "completions". Pre-Story-1.3, '
              'the connectivity path only reset the Firestore network (which '
              'does not resurrect an already-terminated snapshots() stream) '
              'and this count would stay at 1 forever.',
        );

        // And the fresh subscription actually works — a payload delivered on
        // the NEW generation reaches the fleet without throwing.
        gateway.emit('completions', [
          {'firestore_id': 'x'},
        ]);
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('a healthy fleet (no dead channels) is left untouched by '
        'connectivity-online — no needless teardown (AC3)', () async {
      final gateway = _RecorderGateway();
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        gateway: gateway,
        connectivityStream: controller.stream,
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      final openCountsBefore = Map<String, int>.from(gateway.openCounts);
      expect(openCountsBefore['completions'], 1);

      controller.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      expect(
        gateway.openCounts,
        equals(openCountsBefore),
        reason:
            'nothing is dead — connectivity-online must not restart() the '
            'fleet at all, so every channel keeps its original subscription',
      );
    });

    test('rapid offline→online→offline→online flaps coalesce to a single '
        'resubscribe (no thundering herd)', () async {
      final gateway = _RecorderGateway();
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        gateway: gateway,
        connectivityStream: controller.stream,
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      await Future<void>.delayed(Duration.zero);

      gateway.errorAndTerminateCollection(
        'completions',
        Exception('permission-denied (test)'),
      );
      await Future<void>.delayed(Duration.zero);
      final openCountAfterError = gateway.openCounts['completions'];

      // A burst of flaps, all inside the 1.5 s connectivity debounce
      // window.
      controller.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      // Exactly one restart() cycle happened: openCount increased by
      // exactly 1 (restart() = one stop()+start() = one fresh
      // listenToCollection call per channel), not by 2+ for a
      // thundering-herd burst.
      expect(
        gateway.openCounts['completions'],
        openCountAfterError! + 1,
        reason:
            'a burst of flaps inside the debounce window must coalesce '
            'into exactly one resubscribe cycle',
      );
    });
  });

  group('Story 1.3 — tutored fleet resubscribe + park/unpark parity', () {
    test('a dead TUTORED channel + connectivity-online resubscribes it '
        '(park+unpark — TutoredListenerSupervisor has no restart())', () async {
      final ownGateway = _RecorderGateway();
      final tutoredGateway = _RecorderChildGateway();
      final tutoredSupervisor = TutoredListenerSupervisor(
        dispatcher: _NoopDispatcher(),
        resubscribeBackoffBase: _hugeBackoff,
        resubscribeBackoffCap: _hugeBackoff,
      );
      await tutoredSupervisor.attach(
        localProfileId: 99,
        gateway: tutoredGateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );
      addTearDown(tutoredSupervisor.detach);

      expect(tutoredGateway.openCounts['completions'], 1);

      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final orchestrator = _buildOrchestrator(
        gateway: ownGateway,
        connectivityStream: controller.stream,
        resolveTutoredListenerSupervisor: () => tutoredSupervisor,
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      await Future<void>.delayed(Duration.zero);

      tutoredGateway.errorAndTerminateCollection(
        'completions',
        Exception('permission-denied (test)'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tutoredSupervisor.deadChannels, contains('completions'));

      controller.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      expect(
        tutoredGateway.openCounts['completions'],
        greaterThanOrEqualTo(2),
        reason:
            'connectivity-online must park+unpark the tutored fleet when '
            'it has a dead channel, reopening a fresh subscription',
      );
      expect(
        tutoredSupervisor.deadChannels,
        isNot(contains('completions')),
        reason: 'a fresh park+unpark clears the dead-channel bookkeeping',
      );
    });

    test(
      'a healthy tutored fleet is left untouched by connectivity-online',
      () async {
        final ownGateway = _RecorderGateway();
        final tutoredGateway = _RecorderChildGateway();
        final tutoredSupervisor = TutoredListenerSupervisor(
          dispatcher: _NoopDispatcher(),
        );
        await tutoredSupervisor.attach(
          localProfileId: 99,
          gateway: tutoredGateway,
          parentUid: 'parent-uid',
          remoteProfileId: 'child-1',
        );
        addTearDown(tutoredSupervisor.detach);
        final beforeCounts = Map<String, int>.from(tutoredGateway.openCounts);

        final controller = StreamController<bool>();
        addTearDown(controller.close);
        final orchestrator = _buildOrchestrator(
          gateway: ownGateway,
          connectivityStream: controller.stream,
          resolveTutoredListenerSupervisor: () => tutoredSupervisor,
        );
        addTearDown(orchestrator.dispose);

        orchestrator.start();
        await Future<void>.delayed(Duration.zero);

        controller.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        controller.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 1700));

        expect(tutoredGateway.openCounts, equals(beforeCounts));
      },
    );
  });
}
