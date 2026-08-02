/// Unit tests for Phase 1 Story D — account-switch lifecycle.
///
/// Scope (migration-plan Phase 1, "Move listener teardown/rebind onto
/// per-app lifecycle" — the actionable slice): activating a NEW account
/// while another is active must resolve the new account's named app and
/// dispose/release the previous one's, without leaking apps across many
/// switches and without tearing down an app that is still in use. This is
/// risk-register item (a), "named-app teardown leaks native resources →
/// OOM" (`api29-learn-oom`), reproduced here as an in-memory accounting
/// proof — the on-device resource-sanity evidence lives in the Phase 1
/// Story E integration test.
///
/// `activeAccountFirebaseProvider` (`account_firebase_providers.dart`,
/// Story P1-C) already wires this: it watches `activeAccountIdProvider` and
/// re-watches `accountFirebaseProvider(accountId)` for whichever id is
/// current. Riverpod's `autoDispose` family semantics mean the FAMILY MEMBER
/// for an account no longer watched is scheduled for disposal, which the
/// generated `accountFirebase` provider's `ref.onDispose` turns into
/// `AccountFirebase.dispose(accountId)` — a real `app.delete()` in
/// production. This file is the account-SWITCH-shaped proof of that wiring:
/// it does not re-test what `account_firebase_providers_test.dart` already
/// covers (single-switch dispose-of-the-left-account), it extends to N
/// switches, non-adjacent revisits, concurrent/rapid switches, and the
/// bound interaction the plan calls out ("Exceeding it must fail loudly,
/// not silently evict").
///
/// No platform binding, no device, no emulator: mirrors
/// `account_firebase_test.dart`/`account_firebase_providers_test.dart`'s
/// testability seam — every native SDK entry point is injected.
///
/// TQ-6: no wall clock, no I/O, no shared mutable global state between
/// tests (every test builds its own container + registry) — order-
/// independent under `--test-randomize-ordering-seed=random`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show MaxAccountsReachedException, kMaxDeviceAccounts;
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ──────────────────────────────────────────────────────────────────

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

const _options = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'test-project',
);

/// Records every `initializeApp`/`delete` call the wrapped [AccountFirebase]
/// makes, keyed by app name, so a test can reconstruct the exact sequence of
/// creates/tears-down a chain of account switches produced. Optionally
/// delays `delete` to simulate a slow/async teardown racing a fast switch.
///
/// **`listApps` models the REAL SDK's "still listed while deleting" window**
/// (test-blindness fix): an app name is added to [_nativeAppNames] the
/// instant the fake `initializeApp` "creates" it, and is only REMOVED once
/// the fake `deleteApp` call actually finishes — mirroring
/// `firebase_core_platform_interface`'s `MethodChannelFirebaseApp.delete()`,
/// which only calls `MethodChannelFirebase.appInstances.remove(name)` AFTER
/// `await _api.delete(name)` returns. Pre-this-fix, every harness in this
/// suite stubbed `listApps: () => const []`, so the "reuse an
/// already-listed app" branch in `AccountFirebase._findOrInitializeApp`
/// never ran at all — combined with [_deleteDelay], this harness can now
/// reproduce the real window where a concurrent `resolve()` sees a
/// still-native, about-to-be-deleted app.
class _SwitchHarness {
  _SwitchHarness({Duration? deleteDelay}) : _deleteDelay = deleteDelay;

  final Duration? _deleteDelay;
  final List<String> initializedNames = [];
  final List<String> deletedNames = [];
  final Map<String, MockFirebaseApp> apps = {};
  final Set<String> _nativeAppNames = {};

  AccountFirebase build({int maxAccounts = 5}) {
    return AccountFirebase(
      options: _options,
      maxAccounts: maxAccounts,
      enableAppCheck: false,
      initializeApp:
          ({required String name, required FirebaseOptions options}) async {
            initializedNames.add(name);
            final app = MockFirebaseApp();
            when(() => app.name).thenReturn(name);
            apps[name] = app;
            _nativeAppNames.add(name);
            return app;
          },
      listApps: () => [for (final name in _nativeAppNames) apps[name]!],
      resolveFirestore: (app) {
        final mock = MockFirebaseFirestore();
        when(() => mock.terminate()).thenAnswer((_) async {});
        return mock;
      },
      resolveAuth: (app) => MockFirebaseAuthHandle(),
      deleteApp: (app) async {
        if (_deleteDelay != null) {
          await Future<void>.delayed(_deleteDelay);
        }
        deletedNames.add(app.name);
        _nativeAppNames.remove(app.name);
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Settings());
  });

  /// Switches [container] to [accountId] and waits for
  /// [activeAccountFirebaseProvider] to settle on the new value, mirroring
  /// how a real switch is a discrete, awaited UI action (e.g. behind a PIN
  /// gate) rather than a rebuild storm.
  Future<AccountFirebaseHandles?> switchTo(
    ProviderContainer container,
    String? accountId,
  ) async {
    container.read(activeAccountIdProvider.notifier).setAccountId(accountId);
    // `.future` awaits the provider's settled AsyncValue regardless of
    // whether it resolves to a real handles bundle or null (signed-out) —
    // `activeAccountFirebase`'s body is `async` even on the null-shortcut
    // path, so the AsyncValue still passes through a microtask before
    // settling.
    return container.read(activeAccountFirebaseProvider.future);
  }

  group('sequential account switching — no leaks across many switches', () {
    test(
      'switching through 5 distinct accounts one at a time leaves exactly '
      'the current account active; every prior account is disposed',
      () async {
        final harness = _SwitchHarness();
        final registry = harness.build();
        final container = ProviderContainer(
          overrides: [
            accountFirebaseRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
        addTearDown(sub.close);

        final ids = ['acct-1', 'acct-2', 'acct-3', 'acct-4', 'acct-5'];
        for (final id in ids) {
          final handles = await switchTo(container, id);
          expect(handles?.app.name, 'account_$id');
          // Let the autoDispose teardown of the PREVIOUS family member run
          // to completion before switching again — this is the well-behaved
          // "await the switch" shape a real PIN-gated switch has.
          await pumpEventQueue();

          // The registry's own live-app accounting must show exactly one
          // active account at a time: the current one.
          expect(
            registry.activeAccountIds,
            {id},
            reason:
                'after switching to $id, the registry must show ONLY $id '
                'as active — no accumulation from prior switches',
          );
        }

        expect(
          harness.initializedNames,
          ids.map((id) => 'account_$id').toList(),
        );
        expect(
          harness.deletedNames,
          ids.take(4).map((id) => 'account_$id').toList(),
          reason:
              'every account except the last-entered one must have been '
              'torn down, in the order it was left',
        );
      },
    );

    test(
      'revisiting a previously-left account creates a genuinely NEW app '
      '(not a stale cached handle) — proves dispose actually released it',
      () async {
        final harness = _SwitchHarness();
        final registry = harness.build();
        final container = ProviderContainer(
          overrides: [
            accountFirebaseRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
        addTearDown(sub.close);

        final firstVisitA = await switchTo(container, 'acct-A');
        await pumpEventQueue();
        await switchTo(container, 'acct-B');
        await pumpEventQueue();
        final secondVisitA = await switchTo(container, 'acct-A');
        await pumpEventQueue();

        expect(
          identical(firstVisitA, secondVisitA),
          isFalse,
          reason:
              'the second visit to acct-A must be a fresh resolve, not the '
              'stale handles object from before it was disposed',
        );
        expect(harness.initializedNames, [
          'account_acct-A',
          'account_acct-B',
          'account_acct-A',
        ]);
        expect(harness.deletedNames, ['account_acct-A', 'account_acct-B']);
        expect(registry.activeAccountIds, {'acct-A'});
      },
    );

    test('cycling through 8 distinct accounts (more than the 5-account bound) '
        'one-at-a-time never exceeds 1 concurrently active account and never '
        'trips MaxAccountsReachedException, because each is disposed before '
        'the next is resolved', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(); // default maxAccounts = 5
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      for (var i = 0; i < 8; i++) {
        final id = 'acct-$i';
        await switchTo(container, id);
        await pumpEventQueue();
        expect(registry.activeAccountIds, {id});
      }

      expect(harness.initializedNames.length, 8);
      expect(harness.deletedNames.length, 7);
    });

    test('switching to null (sign-out) disposes the previously-active account '
        'and leaves the registry with zero active accounts', () async {
      final harness = _SwitchHarness();
      final registry = harness.build();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      await switchTo(container, 'acct-A');
      await pumpEventQueue();
      expect(registry.activeAccountIds, {'acct-A'});

      final afterSignOut = await switchTo(container, null);
      await pumpEventQueue();

      expect(afterSignOut, isNull);
      expect(harness.deletedNames, ['account_acct-A']);
      expect(registry.activeAccountIds, isEmpty);
    });
  });

  group('switching to the same account id is a true no-op', () {
    test('setting the active account id to its current value never re-creates '
        'or disposes the app', () async {
      final harness = _SwitchHarness();
      final registry = harness.build();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      await switchTo(container, 'acct-A');
      await pumpEventQueue();
      await switchTo(container, 'acct-A');
      await pumpEventQueue();

      expect(harness.initializedNames, ['account_acct-A']);
      expect(harness.deletedNames, isEmpty);
    });
  });

  group('rapid switching (no await between switches) still converges '
      'cleanly once settled', () {
    test('firing 3 switches back-to-back without awaiting the intermediate '
        'ones leaves exactly the final account active once the event queue '
        'drains, with every intermediate account disposed', () async {
      final harness = _SwitchHarness();
      final registry = harness.build();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      // Deliberately NOT awaited between calls — simulates a caller
      // (e.g. a rapidly-double-tapped switch affordance) driving the
      // notifier faster than Riverpod's autoDispose scheduling settles.
      container.read(activeAccountIdProvider.notifier).setAccountId('acct-1');
      container.read(activeAccountIdProvider.notifier).setAccountId('acct-2');
      container.read(activeAccountIdProvider.notifier).setAccountId('acct-3');

      final finalHandles = await container.read(
        activeAccountFirebaseProvider.future,
      );
      await pumpEventQueue();

      expect(finalHandles?.app.name, 'account_acct-3');
      expect(
        registry.activeAccountIds,
        {'acct-3'},
        reason:
            'once settled, only the FINAL account of a rapid-switch burst '
            'may remain active — intermediate accounts (acct-1, acct-2) '
            'must not linger',
      );
    });
  });

  group('the ≤5 bound interacts correctly with switching (fails loudly, '
      'never silently evicts)', () {
    test('switching among exactly maxAccounts distinct accounts, each awaited, '
        'never throws — disposal of the left account always completes before '
        'the bound is checked again', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 3);
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      for (final id in ['a', 'b', 'c', 'd', 'e']) {
        await switchTo(container, id);
        await pumpEventQueue();
      }

      expect(registry.activeAccountIds, {'e'});
    });

    test('resolving a genuinely NEW account directly against the bound '
        '(bypassing the provider layer, as a second concurrent caller might) '
        'still throws MaxAccountsReachedException rather than silently '
        'evicting the oldest — the provider layer relies on this registry '
        'contract, it does not soften it', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 2);

      await registry.resolve('acct-A');
      await registry.resolve('acct-B');

      expect(
        () => registry.resolve('acct-C'),
        throwsA(isA<MaxAccountsReachedException>()),
      );
      // The bound is enforced, not evicted around: A and B are still both
      // active, C was never created.
      expect(registry.activeAccountIds, {'acct-A', 'acct-B'});
      expect(harness.initializedNames, ['account_acct-A', 'account_acct-B']);
    });

    // NOTE on methodology: the two tests below deliberately drive
    // `AccountFirebase` DIRECTLY (bypassing the Riverpod `ProviderContainer`
    // entirely), rather than reproducing the race through
    // `activeAccountFirebaseProvider` as the earlier tests in this file do.
    // Going through the real provider chain when the underlying computation
    // is EXPECTED to throw also engages Riverpod 3's built-in
    // retry-with-backoff-on-error behavior (`ProviderElement.triggerRetry`,
    // visible in this package's stack traces) — confirmed, while developing
    // this test, to keep silently retrying the failed resolve for over a
    // minute of real wall-clock time in the background before the test
    // process moved on. That is a real, separately-interesting property of
    // this codebase's Riverpod error handling (a switch that spuriously
    // fails at the bound is NOT a permanent stuck state — Riverpod's own
    // retry loop would eventually succeed once the deferred disposal runs,
    // just with unpredictable, UI-relevant latency), but it makes the
    // characterization test itself slow and non-deterministic. Calling
    // `AccountFirebase.resolve`/`dispose` directly reproduces the EXACT same
    // registry-level race (this is, after all, precisely what
    // `ref.onDispose`'s `unawaited(registry.dispose(accountId))` and the new
    // family member's `registry.resolve(accountId)` each do under the hood)
    // without paying for Riverpod's own recovery machinery.
    test(
      'FINDING (documented, not silently fixed here): resolving a new '
      'account while the previous one is still counted as active — because '
      'its dispose() has not been CALLED yet, modeling the window before '
      "Riverpod's autoDispose scheduler fires the outgoing family member's "
      'ref.onDispose — spuriously throws MaxAccountsReachedException at a '
      'bound exactly equal to the number of accounts already resolved',
      () async {
        final harness = _SwitchHarness();
        final registry = harness.build(maxAccounts: 1);

        await registry.resolve('acct-A');
        // Deliberately NOT disposing acct-A yet — this models the real
        // window between "activeAccountIdProvider moved on" and "Riverpod's
        // scheduler actually invoked ref.onDispose for the acct-A family
        // member", which is where the production race lives.
        expect(
          () => registry.resolve('acct-B'),
          throwsA(isA<MaxAccountsReachedException>()),
          reason:
              'CHARACTERIZATION, not an endorsement: at maxAccounts == '
              'accounts-already-resolved, resolving a new account while the '
              'old one has not yet been disposed throws. See '
              '`accountFirebaseRegistryProvider`\'s doc comment '
              '(account_firebase_providers.dart) for the production fix '
              '(+1 headroom) and the test immediately below for proof that '
              'headroom resolves exactly this shape.',
        );
      },
    );

    test('THE FIX: with ONE account of headroom over the number already '
        'resolved (kMaxDeviceAccounts + 1 — what '
        '`accountFirebaseRegistryProvider` actually configures in '
        'production), the same not-yet-disposed-old-account shape resolves '
        'the new account cleanly, and steady state still settles back to a '
        'single active account once dispose is actually called', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 2); // 1 resolved + 1 headroom

      await registry.resolve('acct-A');
      // Still not disposed — same shape as the FINDING test above, just
      // with the production headroom value.
      final handlesB = await registry.resolve('acct-B');
      expect(handlesB.app.name, 'account_acct-B');
      expect(registry.activeAccountIds, {'acct-A', 'acct-B'});

      // Now the deferred dispose actually runs (mirrors Riverpod's
      // scheduler eventually firing ref.onDispose for acct-A) — steady
      // state settles back to a single active account; the headroom slot
      // was transient absorption, not a permanent second slot.
      await registry.dispose('acct-A');
      expect(registry.activeAccountIds, {'acct-B'});
      expect(harness.deletedNames, ['account_acct-A']);
    });

    test('the wired production registry (accountFirebaseRegistryProvider, no '
        'override) is configured with exactly kMaxDeviceAccounts + 1 — the '
        'headroom value the fix above relies on', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(accountFirebaseRegistryProvider);
      expect(registry.maxAccounts, kMaxDeviceAccounts + 1);
    });
  });
}
