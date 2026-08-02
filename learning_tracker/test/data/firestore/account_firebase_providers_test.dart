/// Unit tests for the `AccountFirebase` Riverpod resolution layer (Phase 1
/// Story C), `lib/data/firestore/account_firebase_providers.dart`.
///
/// No platform binding, no device, no emulator — mirrors
/// `test/data/firestore/account_firebase_test.dart`'s testability seam:
/// every native SDK entry point the wrapped [AccountFirebase] registry
/// touches is injected, and `accountFirebaseRegistryProvider` itself is
/// overridden with that pre-built fake registry so `Firebase.
/// initializeApp` is never reached in this file at all (flag-ON tests) or
/// [firebaseFirestoreProvider]/[firebaseAuthInstanceProvider] are
/// overridden with mocktail fakes (flag-OFF tests).
///
/// TQ-6: no wall clock, no I/O, no shared mutable global state between
/// tests (every test builds its own container + registry) — order-
/// independent under `--test-randomize-ordering-seed=random`.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
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

/// Builds an [AccountFirebase] with every native SDK entry point recorded
/// via a simple in-memory map, mirroring `account_firebase_test.dart`'s
/// `_Recording*` fakes but collapsed into one helper since this file only
/// needs to observe "which app names were created/deleted", not the finer
/// per-call assertions the registry's own unit tests already cover.
class _FakeRegistryHarness {
  final List<String> initializedNames = [];
  final List<String> deletedNames = [];
  final Map<String, MockFirebaseApp> apps = {};

  /// Mirrors the real SDK's `Firebase.apps`: populated the instant the fake
  /// `initializeApp` "creates" an app, and only cleared once the fake
  /// `deleteApp` call actually finishes — see `_SwitchHarness`'s doc comment
  /// (`account_switch_lifecycle_test.dart`) for the full rationale
  /// (test-blindness fix: every harness in this suite used to stub
  /// `listApps: () => const []`, so the reuse-an-existing-app branch never
  /// ran).
  final Set<String> _nativeAppNames = {};

  AccountFirebase build() {
    return AccountFirebase(
      options: _options,
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
        deletedNames.add(app.name);
        _nativeAppNames.remove(app.name);
      },
    );
  }
}

/// Exposes a real, container-scoped [Ref] usable by tests that need to call
/// [disposeAccountFirebase] (which takes a [Ref], matching every other
/// function in `account_firebase_providers.dart` — the real production
/// caller is a widget/notifier with its own `ref`, not a bare
/// [ProviderContainer]). A plain (non-autoDispose) `Provider` stays mounted
/// for the container's whole lifetime, so the `ref` it hands back remains
/// safe to call `.read`/`.invalidate` on for as long as the container itself
/// is alive — exactly the tests' lifetime here.
final _refProvider = Provider<Ref>((ref) => ref);

Ref _refOf(ProviderContainer container) => container.read(_refProvider);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Settings());
  });

  group('accountFirebaseProvider — flag ON (default): routes through the '
      'registry', () {
    test('resolves the requested account\'s handles via AccountFirebase, '
        'never touching the legacy singleton providers', () async {
      final harness = _FakeRegistryHarness();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(container.dispose);

      final handles = await container.read(
        accountFirebaseProvider('acct-A').future,
      );

      expect(handles.app.name, 'account_acct-A');
      expect(harness.initializedNames, ['account_acct-A']);
      // The legacy default-app singleton providers must never even be
      // initialized on the flag-ON path (AD-2: "no bare
      // FirebaseFirestore.instance/FirebaseAuth.instance").
      expect(container.exists(firebaseFirestoreProvider), isFalse);
      expect(container.exists(firebaseAuthInstanceProvider), isFalse);
    });

    test(
      'two different account ids resolve to two distinct named apps',
      () async {
        final harness = _FakeRegistryHarness();
        final container = ProviderContainer(
          overrides: [
            accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
          ],
        );
        addTearDown(container.dispose);

        final handlesA = await container.read(
          accountFirebaseProvider('acct-A').future,
        );
        final handlesB = await container.read(
          accountFirebaseProvider('acct-B').future,
        );

        expect(handlesA.app.name, isNot(handlesB.app.name));
        expect(harness.initializedNames, ['account_acct-A', 'account_acct-B']);
      },
    );

    test('re-watching the same account id never re-creates the app '
        '(idempotent resolve — "must not create/destroy apps on widget '
        'rebuilds")', () async {
      final harness = _FakeRegistryHarness();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(
        accountFirebaseProvider('acct-A').future,
      );
      // A second, independent listener on the SAME family key simulates a
      // widget rebuild re-subscribing.
      final second = await container.read(
        accountFirebaseProvider('acct-A').future,
      );

      expect(identical(first, second), isTrue);
      expect(harness.initializedNames, ['account_acct-A']);
    });
  });

  group('activeAccountFirebaseProvider — switching the active account '
      'never disposes (keepAlive)', () {
    test('HEADLINE: A → B → A within one container creates A exactly ONCE, '
        'never calls terminate()/delete() on the switch, and A\'s original '
        'handles remain the exact same (usable) object throughout — this is '
        'the defect the keepAlive change exists to prevent (a same-process '
        'dispose→re-resolve of the same account hands cloud_firestore\'s '
        'statically-cached, now-terminate()d FirebaseFirestore instance back '
        'to `.settings =`, which throws)', () async {
      final harness = _FakeRegistryHarness();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeAccountIdProvider.notifier).setAccountId('acct-A');
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      final handlesA1 = await container.read(
        activeAccountFirebaseProvider.future,
      );
      expect(handlesA1?.app.name, 'account_acct-A');

      container.read(activeAccountIdProvider.notifier).setAccountId('acct-B');
      final handlesB = await container.read(
        activeAccountFirebaseProvider.future,
      );
      expect(handlesB?.app.name, 'account_acct-B');

      container.read(activeAccountIdProvider.notifier).setAccountId('acct-A');
      final handlesA2 = await container.read(
        activeAccountFirebaseProvider.future,
      );

      // Drain the event queue — if anything WERE scheduled to dispose A
      // (the pre-fix autoDispose behaviour), this gives it every chance
      // to run before the assertions below.
      await pumpEventQueue();

      expect(
        harness.initializedNames,
        ['account_acct-A', 'account_acct-B'],
        reason:
            'account_acct-A must be created exactly ONCE across the '
            'whole A→B→A round trip — no second initializeApp for A',
      );
      expect(
        harness.deletedNames,
        isEmpty,
        reason:
            'switching the active account must never call '
            'terminate()/delete() — that is now reserved for explicit '
            'removal (disposeAccountFirebase) or process teardown',
      );
      expect(
        identical(handlesA1, handlesA2),
        isTrue,
        reason:
            'revisiting acct-A must hand back the SAME handles bundle '
            'produced on the first visit, not a fresh resolve',
      );
      expect(
        handlesA2?.isDisposed,
        isFalse,
        reason:
            'A\'s handles must still be live/usable after the round '
            'trip through B',
      );
      expect(
        container.read(accountFirebaseRegistryProvider).activeAccountIds,
        {'acct-A', 'acct-B'},
        reason:
            'BOTH accounts stay resolved simultaneously under keepAlive '
            '— this is the whole point: switching accumulates instead '
            'of tearing down',
      );
    });

    test('yields different (both still-live) handles for a different account, '
        'and disposes neither', () async {
      final harness = _FakeRegistryHarness();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeAccountIdProvider.notifier).setAccountId('acct-A');
      final sub = container.listen(activeAccountFirebaseProvider, (_, _) {});
      addTearDown(sub.close);

      final handlesA = await container.read(
        activeAccountFirebaseProvider.future,
      );
      expect(handlesA?.app.name, 'account_acct-A');
      expect(harness.deletedNames, isEmpty);

      container.read(activeAccountIdProvider.notifier).setAccountId('acct-B');
      final handlesB = await container.read(
        activeAccountFirebaseProvider.future,
      );

      expect(handlesB?.app.name, 'account_acct-B');
      expect(
        identical(handlesA, handlesB),
        isFalse,
        reason: 'switching accounts must yield a different handles bundle',
      );

      await pumpEventQueue();

      expect(
        harness.deletedNames,
        isEmpty,
        reason:
            'switching the active account must dispose NEITHER the '
            'account being left NOR the one being entered',
      );
      expect(handlesA?.isDisposed, isFalse);
      expect(handlesB?.isDisposed, isFalse);
    });
  });

  group('disposeAccountFirebase — explicit removal DOES dispose', () {
    test('terminates the Firestore handle then deletes the app, in that '
        'order, and does not touch any other resolved account', () async {
      final callOrder = <String>[];
      final harness = _FakeRegistryHarness();
      final registry = AccountFirebase(
        options: _options,
        enableAppCheck: false,
        initializeApp:
            ({required String name, required FirebaseOptions options}) async {
              harness.initializedNames.add(name);
              final app = MockFirebaseApp();
              when(() => app.name).thenReturn(name);
              return app;
            },
        listApps: () => const [],
        resolveFirestore: (app) {
          final mock = MockFirebaseFirestore();
          when(() => mock.terminate()).thenAnswer((_) async {
            callOrder.add('terminate:${app.name}');
          });
          return mock;
        },
        resolveAuth: (app) => MockFirebaseAuthHandle(),
        deleteApp: (app) async {
          callOrder.add('delete:${app.name}');
          harness.deletedNames.add(app.name);
        },
      );

      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      final handlesA = await container.read(
        accountFirebaseProvider('acct-A').future,
      );
      final handlesB = await container.read(
        accountFirebaseProvider('acct-B').future,
      );
      expect(handlesA.isDisposed, isFalse);

      await disposeAccountFirebase(_refOf(container), 'acct-A');

      expect(
        callOrder,
        ['terminate:account_acct-A', 'delete:account_acct-A'],
        reason:
            'defect #3\'s ordering (terminate() before delete()) must '
            'hold for the explicit-removal path too',
      );
      expect(handlesA.isDisposed, isTrue);
      expect(
        registry.activeAccountIds,
        {'acct-B'},
        reason: 'removing acct-A must not touch acct-B, which stays resolved',
      );
      expect(handlesB.isDisposed, isFalse);
    });

    test('after removal, re-resolving the same account id triggers a genuinely '
        'fresh resolve (a second initializeApp), never the stale cached '
        'handles', () async {
      final harness = _FakeRegistryHarness();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(
        accountFirebaseProvider('acct-A').future,
      );
      await disposeAccountFirebase(_refOf(container), 'acct-A');

      final second = await container.read(
        accountFirebaseProvider('acct-A').future,
      );

      expect(identical(first, second), isFalse);
      expect(harness.initializedNames, ['account_acct-A', 'account_acct-A']);
      expect(harness.deletedNames, ['account_acct-A']);
    });
  });

  group(
    'RED-DEMO: reverting accountFirebaseProvider to autoDispose would break '
    'the A→B→A invariant the keepAlive fix exists for',
    () {
      test('a hand-rolled autoDispose-family analogue of the PRE-FIX '
          'accountFirebaseProvider (same resolve/onDispose body, just '
          'without `keepAlive: true`) recreates acct-A a SECOND time and '
          'tears it down mid-round-trip — the exact symptoms the headline '
          'test above proves no longer happen', () async {
        final harness = _FakeRegistryHarness();
        final registry = harness.build();

        // The pre-fix shape of `accountFirebase`: a plain autoDispose
        // family with the same resolve + onDispose wiring, minus
        // `keepAlive: true`.
        final legacyAccountFirebase = FutureProvider.autoDispose
            .family<AccountFirebaseHandles, String>((ref, accountId) async {
              ref.onDispose(() => unawaited(registry.dispose(accountId)));
              return registry.resolve(accountId);
            });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // A → B → A, driven exactly like the real
        // activeAccountFirebaseProvider does (a single listener that
        // re-watches whichever id is "active"), so losing the listener
        // on A when the "active" id moves to B is what schedules A's
        // autoDispose teardown.
        ProviderSubscription<AsyncValue<AccountFirebaseHandles>>? current;
        Future<AccountFirebaseHandles> switchTo(String id) {
          current?.close();
          current = container.listen(legacyAccountFirebase(id), (_, _) {});
          return container.read(legacyAccountFirebase(id).future);
        }

        final handlesA1 = await switchTo('acct-A');
        await pumpEventQueue();
        await switchTo('acct-B');
        await pumpEventQueue();
        final handlesA2 = await switchTo('acct-A');
        current?.close();

        expect(
          harness.initializedNames,
          ['account_acct-A', 'account_acct-B', 'account_acct-A'],
          reason:
              'PRE-FIX SYMPTOM: acct-A is created a SECOND time — the '
              'keepAlive fix\'s headline test asserts this list has '
              'exactly ONE account_acct-A entry; under autoDispose it '
              'does not',
        );
        expect(
          harness.deletedNames,
          ['account_acct-A'],
          reason:
              'PRE-FIX SYMPTOM: switching away from A calls '
              'terminate()/delete() on it — the keepAlive fix\'s '
              'headline test asserts deletedNames stays empty across a '
              'switch; under autoDispose it does not',
        );
        expect(
          identical(handlesA1, handlesA2),
          isFalse,
          reason:
              'PRE-FIX SYMPTOM: revisiting A is a fresh resolve, not the '
              'same object the keepAlive fix guarantees',
        );
      });
    },
  );

  group('accountFirebaseProvider — flag OFF: legacy single-instance '
      'fallback is genuinely reachable', () {
    test('returns a shim built from the legacy singleton providers and '
        'never touches AccountFirebase at all', () async {
      final legacyFirestore = MockFirebaseFirestore();
      final legacyApp = MockFirebaseApp();
      when(() => legacyApp.name).thenReturn('[DEFAULT]');
      when(() => legacyFirestore.app).thenReturn(legacyApp);
      final legacyAuth = MockFirebaseAuthHandle();

      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryEnabledProvider.overrideWithValue(false),
          firebaseFirestoreProvider.overrideWithValue(legacyFirestore),
          firebaseAuthInstanceProvider.overrideWithValue(legacyAuth),
        ],
      );
      addTearDown(container.dispose);

      final handles = await container.read(
        accountFirebaseProvider('acct-A').future,
      );

      expect(identical(handles.firestore, legacyFirestore), isTrue);
      expect(identical(handles.auth, legacyAuth), isTrue);
      expect(identical(handles.app, legacyApp), isTrue);
      // The registry itself must never be constructed on the flag-OFF
      // path — this is the "rollback is a flag flip, no data written
      // through the registry" contract (migration-plan Phase 1).
      expect(container.exists(accountFirebaseRegistryProvider), isFalse);
    });

    test('flag ON vs OFF for the SAME account id produce handles from '
        'different sources (registry app vs. legacy default app)', () async {
      final harness = _FakeRegistryHarness();
      final legacyFirestore = MockFirebaseFirestore();
      final legacyApp = MockFirebaseApp();
      when(() => legacyApp.name).thenReturn('[DEFAULT]');
      when(() => legacyFirestore.app).thenReturn(legacyApp);
      final legacyAuth = MockFirebaseAuthHandle();

      final onContainer = ProviderContainer(
        overrides: [
          accountFirebaseRegistryEnabledProvider.overrideWithValue(true),
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(onContainer.dispose);
      final offContainer = ProviderContainer(
        overrides: [
          accountFirebaseRegistryEnabledProvider.overrideWithValue(false),
          firebaseFirestoreProvider.overrideWithValue(legacyFirestore),
          firebaseAuthInstanceProvider.overrideWithValue(legacyAuth),
        ],
      );
      addTearDown(offContainer.dispose);

      final onHandles = await onContainer.read(
        accountFirebaseProvider('acct-A').future,
      );
      final offHandles = await offContainer.read(
        accountFirebaseProvider('acct-A').future,
      );

      expect(onHandles.app.name, 'account_acct-A');
      expect(offHandles.app.name, '[DEFAULT]');
      expect(identical(onHandles.firestore, offHandles.firestore), isFalse);
    });
  });

  group('accountFirebaseProvider — disposed mid-resolve does not leak the '
      'app (defect #1 red-demo)', () {
    test(
      'a provider disposed while resolve() is still awaiting a slow native '
      'initializeApp() still tears the app down once resolve() settles — '
      'every OTHER harness in this file settles in a single microtask, '
      'which is exactly why this disposed-mid-resolve window never existed '
      'in this suite before this test\n\n'
      'ADAPTED FOR KEEPALIVE (structurally-moot trigger note): pre-keepAlive, '
      'this test disposed the provider instance by dropping its only '
      'listener (`sub.close()`), which used to schedule autoDispose '
      'teardown. Under `keepAlive`, losing the last listener no longer '
      'disposes anything — that trigger is gone. The `!ref.mounted` guard '
      'and the "onDispose registered before the await" ordering this test '
      'exists to prove are still fully reachable, just via the NEW '
      'disposal trigger this story introduces: `container.invalidate(...)` '
      '(what `disposeAccountFirebase` calls internally). Everything else '
      'about the defect #1 fix this test characterizes is unchanged.',
      () async {
        final releaseInit = Completer<void>();
        final initializedNames = <String>[];
        final deletedNames = <String>[];

        final registry = AccountFirebase(
          options: _options,
          enableAppCheck: false,
          initializeApp:
              ({required String name, required FirebaseOptions options}) async {
                // Genuinely yields to the event loop instead of settling in
                // the same microtask — this is the real-world "hundreds of
                // ms of native initializeApp" window the fix targets.
                await releaseInit.future;
                initializedNames.add(name);
                final app = MockFirebaseApp();
                when(() => app.name).thenReturn(name);
                return app;
              },
          listApps: () => const [],
          resolveFirestore: (app) {
            final mock = MockFirebaseFirestore();
            when(() => mock.terminate()).thenAnswer((_) async {});
            return mock;
          },
          resolveAuth: (app) => MockFirebaseAuthHandle(),
          deleteApp: (app) async {
            deletedNames.add(app.name);
          },
        );

        final container = ProviderContainer(
          overrides: [
            accountFirebaseRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);

        // Start resolving 'acct-A' (a listener kicks the build off
        // synchronously, exactly like the pre-keepAlive version of this test
        // did), then explicitly invalidate it — the keepAlive-era equivalent
        // of "dispose this provider instance" (what `disposeAccountFirebase`
        // calls internally) — before the native initializeApp settles. This
        // disposes the provider instance while `registry.resolve` is still in
        // flight, the exact window defect #1 lives in.
        final sub = container.listen(
          accountFirebaseProvider('acct-A'),
          (_, _) {},
        );
        addTearDown(sub.close);
        container.invalidate(accountFirebaseProvider('acct-A'));
        // Drain the event queue so Riverpod's `ProviderScheduler` actually
        // RUNS the scheduled disposal now, WHILE resolve() is still
        // suspended on `releaseInit` (not yet completed) — this is what
        // makes the window real: the disposal must complete (marking
        // `ref.mounted` false) before resolve() settles, not after.
        // Without this drain, completing `releaseInit` immediately lets
        // resolve() race ahead of the scheduler via microtasks alone and
        // "accidentally" win, masking the bug this test targets.
        await pumpEventQueue();

        // Let the slow initializeApp actually settle now that the provider
        // is already disposed.
        releaseInit.complete();
        // Drain the event queue so resolve() completes, the
        // `!ref.mounted` guard fires, and the onDispose-triggered
        // registry.dispose() runs to completion.
        await pumpEventQueue();

        expect(
          initializedNames,
          ['account_acct-A'],
          reason:
              'the in-flight native call still completes (it cannot be '
              'cancelled mid-flight) — the fix is about what happens '
              'AFTER it settles, not preventing the native call itself',
        );
        expect(
          deletedNames,
          ['account_acct-A'],
          reason:
              'CRITICAL: once disposed mid-resolve, the app resolve() went '
              'on to create must still be torn down. Pre-fix, '
              'ref.onDispose was registered AFTER the await, so '
              'registering it in this exact disposed-mid-resolve window '
              'threw UnmountedRefException instead of ever running — the '
              'app (+ its 20 MiB persistent cache) would then be pinned '
              'for the rest of the process.',
        );
        expect(registry.activeAccountIds, isEmpty);
      },
    );
  });

  group('injection seams preserved (AD-2/AD-28 ratchet fallback default)', () {
    test('firebaseFirestoreProvider still returns a FirebaseFirestore '
        'independently of the registry (its public Provider<T> contract is '
        'untouched by this story)', () {
      // Regression guard: dozens of existing call sites
      // (tutored_pull_providers.dart, outbox_providers.dart, and their
      // tests) depend on reading firebaseFirestoreProvider directly, with
      // no dependency on AccountFirebase — overriding it (exactly as those
      // tests already do) must keep working unmodified.
      final mockFirestore = MockFirebaseFirestore();
      final container = ProviderContainer(
        overrides: [firebaseFirestoreProvider.overrideWithValue(mockFirestore)],
      );
      addTearDown(container.dispose);
      expect(
        identical(container.read(firebaseFirestoreProvider), mockFirestore),
        isTrue,
      );
    });

    test('FirebaseAuthGatewayImpl still accepts an injected FirebaseAuth '
        'fake (the seam every existing auth test relies on)', () {
      final fake = MockFirebaseAuthHandle();
      when(() => fake.currentUser).thenReturn(null);
      final gateway = FirebaseAuthGatewayImpl(firebaseAuth: fake);
      expect(gateway.currentUser, isNull);
    });
  });
}
