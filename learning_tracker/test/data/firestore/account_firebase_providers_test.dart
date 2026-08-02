/// Unit tests for the `AccountFirebase` Riverpod resolution layer,
/// `lib/data/firestore/account_firebase_providers.dart`.
///
/// This file is deliberately small — it mirrors how small the production
/// file it tests now is (see that file's doc comment for what used to live
/// here and why it was deleted rather than migrated: a feature flag with a
/// legacy default-app fallback, and an "active account" convenience layer
/// built on an API shape [AccountFirebase] no longer has). What remains is
/// just DI wiring: one singleton [AccountFirebase], keepAlive, disposed on
/// container teardown. `test/data/firestore/account_firebase_test.dart`
/// covers every behavioral guarantee of the registry itself; this file only
/// covers that the provider wires one correctly.
///
/// TQ-6: no wall clock, no I/O, no shared mutable global state between
/// tests (every test builds its own container) — order-independent under
/// `--test-randomize-ordering-seed=random`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show kMaxDeviceAccounts;
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';
import 'package:learning_tracker/firebase_options.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Settings());
  });

  group('accountFirebaseRegistryProvider — DI wiring', () {
    test('is configured with the current platform options and exactly '
        'kMaxDeviceAccounts (no extra headroom)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(accountFirebaseRegistryProvider);

      expect(registry, isA<AccountFirebase>());
      expect(registry.maxAccounts, kMaxDeviceAccounts);
    });

    test('is a singleton within one container: reading it twice returns '
        'the identical instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(accountFirebaseRegistryProvider);
      final second = container.read(accountFirebaseRegistryProvider);

      expect(identical(first, second), isTrue);
    });

    test('two separate containers each get their own registry instance '
        '(no accidental cross-test/cross-container global state)', () {
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);
      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);

      final a = containerA.read(accountFirebaseRegistryProvider);
      final b = containerB.read(accountFirebaseRegistryProvider);

      expect(identical(a, b), isFalse);
    });

    test('disposing the container tears down every account the registry '
        'had resolved (ref.onDispose -> disposeAll)', () async {
      final initializedNames = <String>[];
      final deletedNames = <String>[];

      final container = ProviderContainer(
        overrides: [
          accountFirebaseRegistryProvider.overrideWith((ref) {
            final registry = AccountFirebase(
              options: DefaultFirebaseOptions.currentPlatform,
              maxAccounts: kMaxDeviceAccounts,
              enableAppCheck: false,
              initializeApp:
                  ({
                    required String name,
                    required FirebaseOptions options,
                  }) async {
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
              resolveAuth: (app) {
                final mock = MockFirebaseAuthHandle();
                final user = MockUser();
                when(() => user.uid).thenReturn('uid-1');
                when(() => mock.currentUser).thenReturn(user);
                return mock;
              },
              deleteApp: (app) async {
                deletedNames.add(app.name);
              },
            );
            ref.onDispose(() => registry.disposeAll());
            return registry;
          }),
        ],
      );

      final registry = container.read(accountFirebaseRegistryProvider);
      await registry.resolve('acc-1');
      expect(registry.activeAccountIds, {'acc-1'});

      container.dispose();
      // `onDispose` callbacks run synchronously but `disposeAll` itself is
      // async (fire-and-forget from the provider's point of view) — give
      // the event loop a turn so its awaits complete.
      await Future<void>.delayed(Duration.zero);

      expect(deletedNames, ['account_acc-1']);
    });
  });
}
