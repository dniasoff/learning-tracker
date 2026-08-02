/// Unit tests for `lib/data/firestore/active_account_providers.dart` — the
/// minimal "which account is active" seam repositories will resolve their
/// Firestore handle through (Epic B).
///
/// Deliberately small, mirroring
/// `test/data/firestore/account_firebase_providers_test.dart`'s own scope
/// note: this only covers the notifier + resolution wiring added here, not
/// [AccountFirebase]'s own behavioral guarantees (covered by
/// `account_firebase_test.dart`).
///
/// A `container.read(activeAccountFirebaseProvider)` only returns the
/// FutureProvider's synchronous `loading` [AsyncValue] — [AccountFirebase
/// .resolve]'s real settle (success or [AccountNotAuthenticatedException])
/// arrives one or more async hops later (through the mock Auth's
/// `authStateChanges()` stream). [_readSettled] drains the event queue via
/// `pumpEventQueue()` before re-reading, the same established pattern
/// `test/core/preferences/preference_providers_test.dart` uses for the
/// identical "one async hop after build()" shape.
///
/// TQ-6: no wall clock, no I/O, no shared mutable global state between
/// tests — every test builds its own [ProviderContainer], order-independent
/// under `--test-randomize-ordering-seed=random`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

/// Builds an [AccountFirebase] wired entirely to fakes/mocks — no platform
/// binding, no network — matching
/// `account_firebase_providers_test.dart`'s own setup.
///
/// [authenticated] mirrors `account_firebase_test.dart`'s
/// never-authenticated-vs-restored Auth mock shapes: `true` (default)
/// simulates an already-signed-in session (`currentUser` non-null from the
/// start — the "restored" case), `false` simulates a brand-new app with
/// nothing signed in (`currentUser` null, `authStateChanges()` emits a
/// single `null`) so [AccountFirebase.resolve] throws
/// [AccountNotAuthenticatedException] exactly as it would for an account
/// id that was never created.
AccountFirebase _fakeRegistry({
  String uid = 'uid-1',
  bool authenticated = true,
}) {
  return AccountFirebase(
    options: const FirebaseOptions(
      apiKey: 'k',
      appId: 'a',
      messagingSenderId: 'm',
      projectId: 'p',
    ),
    enableAppCheck: false,
    initializeApp:
        ({required String name, required FirebaseOptions options}) async {
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
    resolveAuth: (app) {
      final mock = MockFirebaseAuthHandle();
      if (authenticated) {
        final user = MockUser();
        when(() => user.uid).thenReturn(uid);
        when(() => mock.currentUser).thenReturn(user);
      } else {
        when(() => mock.currentUser).thenReturn(null);
        when(
          () => mock.authStateChanges(),
        ).thenAnswer((_) => Stream<User?>.value(null));
      }
      return mock;
    },
    deleteApp: (app) async {},
  );
}

/// Triggers [activeAccountFirebaseProvider]'s build via [read] if one is
/// pending, then drains the event queue so [AccountFirebase.resolve]'s
/// async chain settles, and returns the settled [AsyncValue]. See the
/// library doc comment for why a single `read()` alone is not enough.
Future<AsyncValue<AccountFirebaseHandles?>> _readSettled(
  ProviderContainer container,
) async {
  container.read(activeAccountFirebaseProvider);
  await pumpEventQueue();
  return container.read(activeAccountFirebaseProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Settings());
  });

  group('activeAccountIdProvider', () {
    test(
      'defaults to null — nothing is active until something calls set()',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(activeAccountIdProvider), isNull);
      },
    );

    test('set() updates the state; set(null) clears it again', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeAccountIdProvider.notifier).set('acc-1');
      expect(container.read(activeAccountIdProvider), 'acc-1');

      container.read(activeAccountIdProvider.notifier).set(null);
      expect(container.read(activeAccountIdProvider), isNull);
    });
  });

  group('activeAccountFirebaseProvider', () {
    test('resolves to null when no account is active', () async {
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(_fakeRegistry()),
        ],
      );
      addTearDown(container.dispose);

      final value = await _readSettled(container);

      expect(value, const AsyncData<AccountFirebaseHandles?>(null));
    });

    test("resolves to the active account's handles once it has an "
        'authenticated session', () async {
      final registry = _fakeRegistry(uid: 'uid-resolved');
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      // The caller is responsible for establishing the session before
      // marking it active — mirrors the real Epic C contract described in
      // the library doc comment.
      await registry.createAnonymousAccount('acc-1');
      container.read(activeAccountIdProvider.notifier).set('acc-1');

      final value = await _readSettled(container);

      expect(value.hasValue, isTrue, reason: value.toString());
      expect(value.value!.uid, 'uid-resolved');
    });

    test('surfaces AccountNotAuthenticatedException as an AsyncError when set '
        'to an id with no authenticated session — resolve() never creates '
        'one on this provider\'s behalf', () async {
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(
            _fakeRegistry(authenticated: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeAccountIdProvider.notifier).set('never-created');

      final value = await _readSettled(container);

      expect(value.hasError, isTrue, reason: value.toString());
      expect(value.error, isA<AccountNotAuthenticatedException>());
    });

    test("switching the active account id re-resolves to the new account's "
        'handles', () async {
      final registry = _fakeRegistry();
      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      await registry.createAnonymousAccount('acc-1');
      await registry.createAnonymousAccount('acc-2');

      container.read(activeAccountIdProvider.notifier).set('acc-1');
      final first = await _readSettled(container);
      expect(first.value!.app.name, 'account_acc-1');

      container.read(activeAccountIdProvider.notifier).set('acc-2');
      final second = await _readSettled(container);
      expect(second.value!.app.name, 'account_acc-2');
    });
  });
}
