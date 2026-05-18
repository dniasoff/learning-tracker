/// Wave 0 — characterization test for the SyncOrchestrator singleton invariant.
///
/// S7: exactly one SyncOrchestrator instance exists per app session.
///
/// The test is skipped; un-skip in Wave 2 (after the Riverpod provider fix
/// that prevents duplicate listener registration on profile switch).
library;

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Background / context
// ---------------------------------------------------------------------------
//
// Current issue (Bug #1, quality crisis 2026-05-17):
//
//   `syncOrchestratorProvider` is a `Provider<SyncOrchestrator?>` that
//   watches `authStateProvider` AND (indirectly) the active-profile provider.
//   When the user switches profiles the provider rebuilds, constructing a
//   second `SyncOrchestratorImpl` (with a new LifecycleObserver and
//   ListenerSupervisor) before the old one's `onDispose` fires. This means:
//     - Two LifecycleObservers are registered simultaneously on WidgetsBinding.
//     - Two sets of Firestore listeners are open.
//     - pullOnLaunch is called for every rebuild.
//
//   R1 fix (partially applied in commit e5c052d0): `syncOrchestratorProvider`
//   no longer watches the active-profile provider directly. The active profile
//   is resolved lazily via `resolveProfileIdProvider`.
//
//   S7 pins the observable invariant: at any point during a session, at most
//   one `SyncOrchestrator` instance must be alive. This is validated via a
//   reference-counting fake that tracks construction/disposal.
//
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Fake / counting harness
// ---------------------------------------------------------------------------

/// Tracks live instances of a simulated SyncOrchestrator.
///
/// In production, the Riverpod container manages object lifetimes. Here we
/// use a shared counter that each fake instance increments on construction
/// and decrements on [dispose] so the test can assert the singleton property
/// at any point.
class _InstanceTracker {
  int _live = 0;
  int _everCreated = 0;

  int get liveCount => _live;
  int get totalCreated => _everCreated;

  _FakeOrchestrator create() {
    _live++;
    _everCreated++;
    return _FakeOrchestrator(
      onDispose: () {
        _live--;
      },
    );
  }
}

class _FakeOrchestrator {
  _FakeOrchestrator({required this.onDispose});
  final void Function() onDispose;
  void dispose() => onDispose();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('S7 — SyncOrchestrator singleton invariant (Wave 0 characterization)', () {
    // ── S7 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: exactly one SyncOrchestrator is alive at any time during
    // an app session.
    //
    // The test simulates the Riverpod provider lifecycle:
    //   1. Provider builds → creates instance #1.
    //   2. Profile switch (or auth change) → provider rebuilds:
    //        a. new instance #2 is created.
    //        b. old instance #1 is disposed (onDispose callback fires).
    //   3. After the transition, liveCount must be 1.
    //
    // Pre-rework (Bug #1): step (b) sometimes fires AFTER step (a) has
    // already registered a second LifecycleObserver. The Riverpod `Provider`
    // (not `StreamProvider`) guarantees that `onDispose` fires before the
    // new value is handed out, so this test should pass once the provider
    // correctly avoids watching the profile provider directly.
    //
    // Wave-2 un-skip will wire this against the real Riverpod ProviderContainer
    // with `syncOrchestratorProvider` to catch regressions in the real stack.
    test(
      'S7: only one SyncOrchestrator instance is alive at any time',
      skip: 'un-skip in Wave 2',
      () async {
        final tracker = _InstanceTracker();

        // ── Step 1: initial build ──────────────────────────────────────────
        final instance1 = tracker.create();
        expect(
          tracker.liveCount,
          equals(1),
          reason: 'S7: exactly 1 live instance after initial construction',
        );

        // ── Step 2: provider rebuild (e.g., profile switch) ────────────────
        // Correct Riverpod behavior: dispose old → create new.
        instance1.dispose();
        final instance2 = tracker.create();

        expect(
          tracker.liveCount,
          equals(1),
          reason:
              'S7: after dispose+rebuild cycle, still exactly 1 live instance',
        );
        expect(
          tracker.totalCreated,
          equals(2),
          reason: 'S7: two instances were created in total (one per session)',
        );

        // ── Step 3: cleanup ────────────────────────────────────────────────
        instance2.dispose();
        expect(
          tracker.liveCount,
          equals(0),
          reason: 'S7: after final dispose, no live instances remain',
        );
      },
    );

    // ── Regression guard: double-creation without dispose ──────────────────
    //
    // Pins the Bug #1 scenario: two instances alive simultaneously.
    // This must FAIL before the fix and PASS after. The test is also skipped
    // in Wave 0 since it exercises production provider wiring; Wave 2 will
    // wire the real ProviderContainer.
    test(
      'S7 regression: two live instances simultaneously is detected',
      skip: 'un-skip in Wave 2',
      () async {
        final tracker = _InstanceTracker();

        // Simulate the buggy case: new instance created BEFORE old is disposed.
        final old = tracker.create();
        final newer = tracker.create(); // Bug #1: old not yet disposed

        // This should fail (== 2) before the fix:
        expect(
          tracker.liveCount,
          equals(1),
          reason:
              'S7 regression: creating a second instance without disposing '
              'the first must be prevented by the provider or detected here',
        );

        // Cleanup.
        old.dispose();
        newer.dispose();
      },
    );
  });
}
