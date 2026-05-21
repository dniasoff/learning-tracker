/// Tests for the connectivity-driven Firestore network reset added to
/// [SyncOrchestratorImpl] (Bug 6).
///
/// The reset must fire on a genuine offline→online transition (after a short
/// debounce) and **must NOT** fire on:
///   - the seeded initial-value emission (even if the user starts online),
///   - duplicate "still online" emissions,
///   - offline emissions of any kind,
///   - transitions that flip back to offline during the debounce window.
///
/// Together with the lifecycle-observer reset (which only fires on
/// background→foreground transitions), this covers DNS-wedging scenarios
/// where the app stays foregrounded across a network handoff (WiFi↔cell,
/// VPN reconnect, Doze maintenance window).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal [FirestoreGateway] fake — the connectivity-reset path doesn't
/// exercise any gateway method beyond the listener registration (which
/// returns an empty stream so no events arrive during the test).
class _EmptyGateway implements FirestoreGateway {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SyncOrchestratorImpl _buildOrchestrator({
  Stream<bool>? connectivityStream,
  required Future<void> Function() onReset,
}) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => _EmptyGateway(),
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    resolveBackfillGoals: () async => 0,
    connectivityStream: connectivityStream,
    resetFirestoreNetworkOverride: onReset,
  );
}

void main() {
  // LifecycleObserver.start() registers a WidgetsBindingObserver, so a binding
  // must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('connectivity-driven Firestore reset', () {
    test(
      'subscribes to connectivity stream on start and cancels on dispose',
      () async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          connectivityStream: controller.stream,
          onReset: () async {},
        );

        // Before start: no subscription.
        expect(controller.hasListener, isFalse);

        orchestrator.start();

        // After start: subscribed.
        expect(controller.hasListener, isTrue);

        orchestrator.dispose();

        // After dispose: subscription cancelled.
        expect(controller.hasListener, isFalse);
      },
    );

    test(
      'offline→online transition triggers the reset (after debounce)',
      () async {
        var resetCalls = 0;
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          connectivityStream: controller.stream,
          onReset: () async {
            resetCalls++;
          },
        );
        addTearDown(orchestrator.dispose);

        orchestrator.start();

        // Seeded initial value: starts offline.
        controller.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(resetCalls, 0, reason: 'offline emission must not reset');

        // Transition online.
        controller.add(true);
        // Debounce is 1.5 s — before that elapses, no reset.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(resetCalls, 0, reason: 'still inside debounce window');

        // After debounce elapses, the reset fires exactly once.
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        expect(resetCalls, 1, reason: 'offline→online → exactly one reset');
      },
    );

    test('initial-online emission does NOT trigger a reset', () async {
      var resetCalls = 0;
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        connectivityStream: controller.stream,
        onReset: () async {
          resetCalls++;
        },
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();

      // The seeded first emission is "currently online" — the channel is
      // fresh, no need to reset. We need previous=false to reset.
      controller.add(true);

      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(
        resetCalls,
        0,
        reason: 'seeded online emission must not reset a fresh channel',
      );
    });

    test(
      'duplicate "still online" emissions do not retrigger the reset',
      () async {
        var resetCalls = 0;
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          connectivityStream: controller.stream,
          onReset: () async {
            resetCalls++;
          },
        );
        addTearDown(orchestrator.dispose);

        orchestrator.start();

        // Genuine transition: offline → online → reset fires once.
        controller.add(false);
        controller.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 1700));
        expect(resetCalls, 1);

        // Now several spurious "still online" emissions — must not trigger.
        controller.add(true);
        controller.add(true);
        controller.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 1700));
        expect(resetCalls, 1, reason: 'duplicate online emissions are ignored');
      },
    );

    test(
      'flip back to offline during the debounce window cancels the reset',
      () async {
        var resetCalls = 0;
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          connectivityStream: controller.stream,
          onReset: () async {
            resetCalls++;
          },
        );
        addTearDown(orchestrator.dispose);

        orchestrator.start();

        // offline → online schedules the debounced reset.
        controller.add(false);
        controller.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Network flips back to offline mid-debounce — when the timer
        // fires, the in-callback `_lastConnectivity != true` guard must
        // skip the reset call.
        controller.add(false);

        await Future<void>.delayed(const Duration(milliseconds: 1700));
        expect(
          resetCalls,
          0,
          reason:
              'a connection that drops during debounce should not fire the '
              'reset on a now-offline channel',
        );
      },
    );

    test(
      'no connectivity stream supplied → no subscription, no reset',
      () async {
        var resetCalls = 0;
        final orchestrator = _buildOrchestrator(
          onReset: () async {
            resetCalls++;
          },
        );
        addTearDown(orchestrator.dispose);

        orchestrator.start();

        // Nothing happens — no stream to subscribe to.
        await Future<void>.delayed(const Duration(milliseconds: 1700));
        expect(resetCalls, 0);
      },
    );
  });
}
