/// Unit tests for Phase 1 Story D — account-switch lifecycle.
///
/// **Rewritten for the keepAlive change** (the story that made
/// `accountFirebaseProvider` `@Riverpod(keepAlive: true)` instead of a plain
/// `autoDispose` family — see `account_firebase_providers.dart`'s doc
/// comment on `accountFirebase` for the full "why": `cloud_firestore
/// 6.4.1` caches `FirebaseFirestore.instanceFor` in a process-lifetime
/// static map with no eviction hook, so a same-process dispose→re-resolve
/// of the SAME account — exactly what switching A→B→A used to do under the
/// old autoDispose design — would hand `.settings =` a terminate()d cached
/// instance and throw). This file used to prove "switching disposes the
/// account being left"; it now proves the opposite invariant: **switching
/// the active account, however many times, in whatever order, never
/// disposes anything.** Disposal is now reserved for the explicit removal
/// path (`disposeAccountFirebase`, tested in `account_firebase_providers_
/// test.dart`) and process teardown (`accountFirebaseRegistryProvider`'s
/// `ref.onDispose` → `AccountFirebase.disposeAll`).
///
/// Scope (migration-plan Phase 1, "Move listener teardown/rebind onto
/// per-app lifecycle" — the actionable slice, since re-scoped by the
/// keepAlive story): activating a NEW account while another is active must
/// resolve the new account's named app WITHOUT disturbing the previous
/// one's — extended here to N switches, non-adjacent revisits,
/// concurrent/rapid switches, and the ≤5-account bound interaction the plan
/// calls out ("Exceeding it must fail loudly, not silently evict").
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

/// Exposes a real, container-scoped [Ref] so tests can call
/// [disposeAccountFirebase] (which takes a [Ref], matching every other
/// function in `account_firebase_providers.dart`) without a widget/notifier
/// — mirrors `account_firebase_providers_test.dart`'s identical helper. A
/// plain (non-autoDispose) `Provider` stays mounted for the container's
/// whole lifetime, so the `ref` it hands back stays safe to use for as long
/// as the container itself is alive.
final _refProvider = Provider<Ref>((ref) => ref);

Ref _refOf(ProviderContainer container) => container.read(_refProvider);

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

  group('sequential account switching — accumulates active accounts, never '
      'disposes (keepAlive)', () {
    test('switching through 5 distinct accounts one at a time leaves ALL '
        'FIVE active — none is disposed just because it is no longer the '
        'current one', () async {
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
        await pumpEventQueue();
      }

      expect(
        registry.activeAccountIds,
        ids.toSet(),
        reason:
            'every account switched through must STILL be active — '
            'keepAlive means switching accumulates, it never evicts',
      );
      expect(harness.initializedNames, ids.map((id) => 'account_$id').toList());
      expect(
        harness.deletedNames,
        isEmpty,
        reason: 'switching must never call terminate()/delete()',
      );
    });

    test('revisiting a previously-left account returns the SAME cached '
        'handles (never a fresh resolve) — it was never disposed in the '
        'first place', () async {
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
        isTrue,
        reason:
            'the second visit to acct-A must be the SAME cached '
            'handles object as the first — nothing disposed it in '
            'between',
      );
      expect(harness.initializedNames, ['account_acct-A', 'account_acct-B']);
      expect(harness.deletedNames, isEmpty);
      expect(registry.activeAccountIds, {'acct-A', 'acct-B'});
    });

    test('cycling through exactly maxAccounts distinct accounts one-at-a-time '
        'succeeds (all remain concurrently active); the NEXT, '
        '(maxAccounts + 1)-th distinct account throws '
        'MaxAccountsReachedException — switching alone never frees a slot '
        'under keepAlive, unlike the old autoDispose design', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 5);
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      for (var i = 0; i < 5; i++) {
        await switchTo(container, 'acct-$i');
        await pumpEventQueue();
      }
      expect(registry.activeAccountIds.length, 5);

      expect(
        () => registry.resolve('acct-overflow'),
        throwsA(isA<MaxAccountsReachedException>()),
        reason:
            'the bound must still fail loudly once genuinely exhausted '
            '— keepAlive removes the false positive the old design had '
            'at the bound, it does not soften the bound itself',
      );
      expect(harness.deletedNames, isEmpty);
    });

    test('switching to null (sign-out) does NOT dispose the '
        'previously-active account — signing out is just another switch, '
        'not a removal', () async {
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
      expect(
        harness.deletedNames,
        isEmpty,
        reason:
            'acct-A must stay resolved after sign-out — only explicit '
            'removal (disposeAccountFirebase) or process teardown may '
            'dispose it',
      );
      expect(registry.activeAccountIds, {'acct-A'});
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

  group('rapid switching (no await between switches) still converges cleanly '
      'once settled, with nothing ever disposed', () {
    test(
      'firing 3 switches back-to-back without awaiting the intermediate '
      'ones leaves only the FINAL account resolved once the event queue '
      'drains — Riverpod coalesces the rapid activeAccountIdProvider '
      'changes into a single rebuild of activeAccountFirebaseProvider, so '
      'acct-1/acct-2 are never even watched/resolved through the registry '
      '— and, crucially, nothing that WAS resolved is ever disposed by this',
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

        // Deliberately NOT awaited between calls — simulates a caller
        // (e.g. a rapidly-double-tapped switch affordance) driving the
        // notifier faster than each resolve settles.
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
              'only the account activeAccountFirebaseProvider actually '
              'settled on ever reaches the registry in a genuinely '
              'synchronous burst — this is unchanged by keepAlive (it is '
              'about how many times the WATCHING provider itself '
              'rebuilds, not about disposal policy)',
        );
        expect(
          harness.initializedNames,
          ['account_acct-3'],
          reason:
              'acct-1 and acct-2 are never created at all in this exact '
              'synchronous-burst shape, so there is nothing for keepAlive '
              'to keep alive here — the invariant this test protects is '
              'simply that NOTHING gets disposed either',
        );
        expect(harness.deletedNames, isEmpty);
      },
    );

    test('the same idea with EACH switch actually awaited (the well-behaved, '
        'PIN-gated-switch shape) confirms every intermediate account that DID '
        'reach the registry stays resolved once the burst is done — this is '
        'exactly the "sequential switching accumulates" group above, restated '
        'as the direct counterpart to the true-burst test above it', () async {
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

      for (final id in ['acct-1', 'acct-2', 'acct-3']) {
        await switchTo(container, id);
        await pumpEventQueue();
      }

      expect(
        registry.activeAccountIds,
        {'acct-1', 'acct-2', 'acct-3'},
        reason:
            'once each account genuinely reaches the registry, keepAlive '
            'means it stays resolved — no teardown just because '
            'activeAccountFirebaseProvider moved on to the next id',
      );
      expect(harness.deletedNames, isEmpty);
    });
  });

  group('explicit removal (disposeAccountFirebase) — the only thing that frees '
      'a slot', () {
    test('once switching alone has filled every slot, explicitly removing '
        'one account is what allows a genuinely new account to resolve — '
        'switching cannot do this anymore', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 2);
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
      await switchTo(container, 'acct-B');
      await pumpEventQueue();
      expect(registry.activeAccountIds, {'acct-A', 'acct-B'});

      // At the bound: a third distinct account cannot resolve yet.
      expect(
        () => registry.resolve('acct-C'),
        throwsA(isA<MaxAccountsReachedException>()),
      );

      // Explicit removal (NOT a switch) frees acct-A's slot.
      await disposeAccountFirebase(_refOf(container), 'acct-A');
      expect(registry.activeAccountIds, {'acct-B'});
      expect(harness.deletedNames, ['account_acct-A']);

      // Now a third account resolves cleanly.
      final handlesC = await switchTo(container, 'acct-C');
      await pumpEventQueue();
      expect(handlesC?.app.name, 'account_acct-C');
      expect(registry.activeAccountIds, {'acct-B', 'acct-C'});
    });
  });

  group('the ≤5 bound + the +1 headroom cushion, re-characterized for '
      'keepAlive (explicit removal, not switching, is the only remaining '
      'disposal path)', () {
    // NOTE on methodology: the two tests below deliberately drive
    // `AccountFirebase` DIRECTLY (bypassing the Riverpod `ProviderContainer`
    // entirely). See the equivalent note that used to live here pre-
    // keepAlive: going through the real provider chain when the underlying
    // computation is EXPECTED to throw also engages Riverpod 3's built-in
    // retry-with-backoff-on-error behavior, which makes a characterization
    // test slow/non-deterministic. Calling `AccountFirebase.resolve`/
    // `dispose` directly reproduces the exact same registry-level shape
    // `disposeAccountFirebase` and a concurrent `resolve` would hit,
    // without paying for Riverpod's own recovery machinery.
    test('RE-CHARACTERIZED: the race the +1 headroom was originally added '
        'for (a not-yet-disposed outgoing account counted against the '
        'bound while a new account resolves) can still be constructed '
        'directly against the registry — but its PRODUCTION trigger has '
        'changed. It no longer arises from a mere account switch (switching '
        'never calls dispose() at all now); the closest surviving shape is '
        'disposeAccountFirebase() called for an account whose FIRST resolve '
        'is still in flight (_pending, not yet _handles) — dispose() must '
        'await that in-flight resolve before it can remove the entry, so '
        'activeAccountIds briefly still counts it during that await', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 1);

      await registry.resolve('acct-A');
      // Deliberately NOT disposing acct-A yet — models an in-flight (or
      // not-yet-started) dispose racing a concurrent resolve for a
      // genuinely new account.
      expect(
        () => registry.resolve('acct-B'),
        throwsA(isA<MaxAccountsReachedException>()),
        reason:
            'CHARACTERIZATION, not an endorsement: at maxAccounts == '
            'accounts-already-resolved, resolving a new account while '
            'the old one has not yet been disposed throws. See '
            '`accountFirebaseRegistryProvider`\'s doc comment '
            '(account_firebase_providers.dart) for why this residual '
            'shape is much narrower under keepAlive than it was under '
            'the old switch-driven design, and the test immediately '
            'below for proof that headroom still resolves it.',
      );
    });

    test('THE FIX (unchanged): with ONE account of headroom over the number '
        'already resolved (kMaxDeviceAccounts + 1 — what '
        '`accountFirebaseRegistryProvider` actually configures in '
        'production), the same not-yet-disposed-old-account shape resolves '
        'the new account cleanly, and steady state still settles back down '
        'once dispose is actually called', () async {
      final harness = _SwitchHarness();
      final registry = harness.build(maxAccounts: 2); // 1 resolved + 1 headroom

      await registry.resolve('acct-A');
      final handlesB = await registry.resolve('acct-B');
      expect(handlesB.app.name, 'account_acct-B');
      expect(registry.activeAccountIds, {'acct-A', 'acct-B'});

      await registry.dispose('acct-A');
      expect(registry.activeAccountIds, {'acct-B'});
      expect(harness.deletedNames, ['account_acct-A']);
    });

    test('the wired production registry (accountFirebaseRegistryProvider, no '
        'override) is still configured with exactly kMaxDeviceAccounts + 1 '
        '— kept as-is per this story\'s instructions even though the '
        'ORIGINAL (switch-driven) justification for the headroom is now '
        'moot; see the re-characterization test above for the narrower '
        'residual scenario it still covers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(accountFirebaseRegistryProvider);
      expect(registry.maxAccounts, kMaxDeviceAccounts + 1);
    });
  });
}
