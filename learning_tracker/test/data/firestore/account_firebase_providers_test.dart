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
            return app;
          },
      listApps: () => const [],
      resolveFirestore: (app) => MockFirebaseFirestore(),
      resolveAuth: (app) => MockFirebaseAuthHandle(),
      deleteApp: (app) async {
        deletedNames.add(app.name);
      },
    );
  }
}

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

  group('activeAccountFirebaseProvider — switching the active account', () {
    test('yields different handles for a different account and disposes '
        'the previously-active account\'s app', () async {
      final harness = _FakeRegistryHarness();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(harness.build()),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeAccountIdProvider.notifier).setAccountId('acct-A');
      // A keepAlive listener so activeAccountFirebaseProvider itself stays
      // alive across the switch below (only the FAMILY member for the
      // account being left is expected to autoDispose).
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

      // accountFirebaseProvider('acct-A') is no longer watched by anything
      // once activeAccountFirebaseProvider moved on to 'acct-B' — autoDispose
      // teardown is scheduled for the next event-loop tick(s).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        harness.deletedNames,
        ['account_acct-A'],
        reason:
            'switching the active account must dispose exactly the '
            'account being left (account_acct-A), never the one being '
            'entered (account_acct-B) and never both.',
      );
    });
  });

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
