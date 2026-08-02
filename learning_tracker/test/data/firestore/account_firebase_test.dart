/// Unit tests for the `AccountFirebase` registry (Phase 1 Story A),
/// `lib/data/firestore/account_firebase.dart`.
///
/// No platform binding, no device, no emulator: every native SDK entry
/// point the registry touches (`Firebase.initializeApp`, `Firebase.apps`,
/// `FirebaseFirestore.instanceFor`, `FirebaseAuth.instanceFor`,
/// `FirebaseAppCheck.instanceFor`, App Check `.activate()`,
/// `FirebaseApp.delete()`) is injected as a fake/mock per the class's
/// documented testability seam. `mocktail`'s `class MockX extends Mock
/// implements X {}` pattern mirrors
/// `test/core/sync/firestore_instance_provider_test.dart` and
/// `test/core/auth/firebase_auth_gateway_impl_test.dart` — `Mock` overrides
/// `noSuchMethod` and never calls the real SDK constructor, so this is safe
/// without `TestWidgetsFlutterBinding`/Firebase test setup.
///
/// TQ-6: no wall clock, no I/O, no shared mutable global state between
/// tests (every test builds its own registry + fakes) — order-independent
/// under `--test-randomize-ordering-seed=random`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show MaxAccountsReachedException;
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

// ─── Mocks ──────────────────────────────────────────────────────────────────

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

class MockFirebaseAppCheckHandle extends Mock implements FirebaseAppCheck {}

const _options = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'test-project',
);

// ─── Recording fakes (the testability seam) ────────────────────────────────

/// Fakes `Firebase.initializeApp`: hands back a fresh [MockFirebaseApp]
/// stubbed with the requested [name] and records every call, so tests can
/// assert exactly how many times (and with which names) the real SDK
/// entry point would have been hit.
class _RecordingAppInitializer {
  int callCount = 0;
  final List<String> names = [];
  final Map<String, MockFirebaseApp> created = {};

  Future<FirebaseApp> call({
    required String name,
    required FirebaseOptions options,
  }) async {
    callCount++;
    names.add(name);
    final app = MockFirebaseApp();
    when(() => app.name).thenReturn(name);
    created[name] = app;
    return app;
  }
}

/// Fakes `FirebaseFirestore.instanceFor(app:)`: one fresh mock per app name,
/// stashed so a test can retrieve the exact instance the registry handed
/// out and verify `.settings` was assigned on it.
class _RecordingFirestoreResolver {
  final Map<String, MockFirebaseFirestore> created = {};

  FirebaseFirestore call(FirebaseApp app) {
    final mock = MockFirebaseFirestore();
    created[app.name] = mock;
    return mock;
  }
}

class _RecordingAuthResolver {
  final Map<String, MockFirebaseAuthHandle> created = {};

  FirebaseAuth call(FirebaseApp app) {
    final mock = MockFirebaseAuthHandle();
    created[app.name] = mock;
    return mock;
  }
}

class _RecordingAppDeleter {
  int callCount = 0;
  final List<String> deletedAppNames = [];

  Future<void> call(FirebaseApp app) async {
    callCount++;
    deletedAppNames.add(app.name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Settings());
  });

  late _RecordingAppInitializer initializeApp;
  late _RecordingFirestoreResolver resolveFirestore;
  late _RecordingAuthResolver resolveAuth;
  late _RecordingAppDeleter deleteApp;

  AccountFirebase buildRegistry({
    int maxAccounts = 5,
    bool enableAppCheck = false,
    AppCheckResolver? resolveAppCheck,
    AppCheckActivator? activateAppCheck,
    AppLogger? logger,
    FirebaseAppsLister? listApps,
  }) {
    return AccountFirebase(
      options: _options,
      maxAccounts: maxAccounts,
      enableAppCheck: enableAppCheck,
      initializeApp: initializeApp.call,
      listApps: listApps ?? () => const [],
      resolveFirestore: resolveFirestore.call,
      resolveAuth: resolveAuth.call,
      resolveAppCheck: resolveAppCheck,
      activateAppCheck: activateAppCheck,
      deleteApp: deleteApp.call,
      logger: logger ?? AppLogger(Talker()),
    );
  }

  setUp(() {
    initializeApp = _RecordingAppInitializer();
    resolveFirestore = _RecordingFirestoreResolver();
    resolveAuth = _RecordingAuthResolver();
    deleteApp = _RecordingAppDeleter();
  });

  // ── appNameForAccount: pure, no Firebase call ────────────────────────────

  group('appNameForAccount (pure name derivation)', () {
    test('prefixes a well-formed UUID-v4 account id verbatim', () {
      expect(
        AccountFirebase.appNameForAccount(
          '550e8400-e29b-41d4-a716-446655440000',
        ),
        'account_550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('sanitizes characters outside [A-Za-z0-9_-] to underscore', () {
      expect(
        AccountFirebase.appNameForAccount('abc/def.ghi jkl@mno'),
        'account_abc_def_ghi_jkl_mno',
      );
    });

    test('throws ArgumentError on an empty account id', () {
      expect(() => AccountFirebase.appNameForAccount(''), throwsArgumentError);
    });
  });

  // ── resolve(): creation bookkeeping + idempotency ────────────────────────

  group('resolve — idempotent handle creation', () {
    test(
      'a second resolve() for the same account does NOT call '
      'initializeApp again, and returns the identical handles instance',
      () async {
        final registry = buildRegistry();

        final first = await registry.resolve('acc-1');
        final second = await registry.resolve('acc-1');

        expect(initializeApp.callCount, 1);
        expect(identical(first, second), isTrue);
        expect(first.app.name, 'account_acc-1');
      },
    );

    test('two different accounts each get their own named app', () async {
      final registry = buildRegistry();

      final a = await registry.resolve('acc-a');
      final b = await registry.resolve('acc-b');

      expect(initializeApp.callCount, 2);
      expect(a.app.name, isNot(equals(b.app.name)));
      expect(registry.activeAccountIds, {'acc-a', 'acc-b'});
    });

    test('concurrent resolve() calls for the same account dedupe to a '
        'single initializeApp call', () async {
      final registry = buildRegistry();

      final futures = await Future.wait([
        registry.resolve('acc-race'),
        registry.resolve('acc-race'),
        registry.resolve('acc-race'),
      ]);

      expect(initializeApp.callCount, 1);
      expect(identical(futures[0], futures[1]), isTrue);
      expect(identical(futures[1], futures[2]), isTrue);
    });

    test('resolve throws ArgumentError on an empty account id', () async {
      final registry = buildRegistry();
      await expectLater(registry.resolve(''), throwsArgumentError);
      expect(initializeApp.callCount, 0);
    });

    test('reuses an already-initialized native app instead of calling '
        'initializeApp again (defensive re-entry, e.g. object recreated '
        'mid-process)', () async {
      final existingApp = MockFirebaseApp();
      when(() => existingApp.name).thenReturn('account_acc-1');
      final registry = buildRegistry(listApps: () => [existingApp]);

      final handles = await registry.resolve('acc-1');

      expect(initializeApp.callCount, 0);
      expect(identical(handles.app, existingApp), isTrue);
    });
  });

  // ── AD-18: Settings pinned before first use ──────────────────────────────

  group('resolve — AD-18 Settings pinned before first use', () {
    test('assigns bounded, non-unlimited persistence Settings on the '
        'Firestore handle before resolve() returns', () async {
      final registry = buildRegistry();

      final handles = await registry.resolve('acc-1');
      final mockFirestore = resolveFirestore.created['account_acc-1']!;

      final captured = verify(
        () => mockFirestore.settings = captureAny(),
      ).captured;
      expect(captured, hasLength(1));
      final settings = captured.single as Settings;
      expect(settings.persistenceEnabled, isTrue);
      expect(settings.cacheSizeBytes, kAccountFirestoreCacheSizeBytes);
      expect(
        settings.cacheSizeBytes,
        isNot(equals(Settings.CACHE_SIZE_UNLIMITED)),
        reason: 'AD-18 forbids CACHE_SIZE_UNLIMITED (risk register (c))',
      );
      expect(identical(handles.firestore, mockFirestore), isTrue);
    });
  });

  // ── Bound to ≤ maxAccounts, fails loudly ──────────────────────────────────

  group('resolve — bounded account count fails loudly, never evicts', () {
    test(
      'resolving a NEW account past maxAccounts throws '
      'MaxAccountsReachedException and does not touch initializeApp',
      () async {
        final registry = buildRegistry(maxAccounts: 2);
        await registry.resolve('acc-1');
        await registry.resolve('acc-2');
        expect(initializeApp.callCount, 2);

        await expectLater(
          registry.resolve('acc-3'),
          throwsA(isA<MaxAccountsReachedException>()),
        );

        // Loud failure, not silent eviction: the two originally-resolved
        // accounts are still active, and no third app was created.
        expect(initializeApp.callCount, 2);
        expect(registry.activeAccountIds, {'acc-1', 'acc-2'});
      },
    );

    test('re-resolving an already-active account at the bound is allowed '
        '(idempotent resolve is not itself growth)', () async {
      final registry = buildRegistry(maxAccounts: 1);
      final first = await registry.resolve('acc-1');

      final second = await registry.resolve('acc-1');

      expect(identical(first, second), isTrue);
      expect(initializeApp.callCount, 1);
    });

    test('constructor rejects a non-positive maxAccounts', () {
      expect(
        () => AccountFirebase(options: _options, maxAccounts: 0),
        throwsArgumentError,
      );
    });
  });

  // ── dispose(): genuinely complete, testably so ───────────────────────────

  group('dispose — releases the app and is safe to re-create afterwards', () {
    test('deletes the app exactly once and clears active state', () async {
      final registry = buildRegistry();
      await registry.resolve('acc-1');

      await registry.dispose('acc-1');

      expect(deleteApp.callCount, 1);
      expect(deleteApp.deletedAppNames, ['account_acc-1']);
      expect(registry.isActive('acc-1'), isFalse);
      expect(registry.activeAccountIds, isEmpty);
    });

    test('is a safe no-op for an account with no active handles', () async {
      final registry = buildRegistry();

      await registry.dispose('never-resolved');

      expect(deleteApp.callCount, 0);
    });

    test('calling dispose twice in a row only deletes once', () async {
      final registry = buildRegistry();
      await registry.resolve('acc-1');

      await registry.dispose('acc-1');
      await registry.dispose('acc-1');

      expect(deleteApp.callCount, 1);
    });

    test('dispose-then-resolve creates a genuinely NEW app (proves the old '
        'handle was actually released, not just hidden)', () async {
      final registry = buildRegistry();
      final before = await registry.resolve('acc-1');

      await registry.dispose('acc-1');
      final after = await registry.resolve('acc-1');

      expect(initializeApp.callCount, 2);
      expect(identical(before, after), isFalse);
      expect(registry.isActive('acc-1'), isTrue);
    });

    test('disposeAll tears down every active account', () async {
      final registry = buildRegistry();
      await registry.resolve('acc-1');
      await registry.resolve('acc-2');
      await registry.resolve('acc-3');

      await registry.disposeAll();

      expect(deleteApp.callCount, 3);
      expect(registry.activeAccountIds, isEmpty);
    });
  });

  // ── App Check: best-effort, non-fatal ────────────────────────────────────

  group('resolve — App Check resolution is best-effort and non-fatal', () {
    test('resolves and activates App Check when enabled', () async {
      final mockAppCheck = MockFirebaseAppCheckHandle();
      var activateCalled = false;
      final registry = buildRegistry(
        enableAppCheck: true,
        resolveAppCheck: (app) => mockAppCheck,
        activateAppCheck: (appCheck) async {
          activateCalled = true;
          expect(identical(appCheck, mockAppCheck), isTrue);
        },
      );

      final handles = await registry.resolve('acc-1');

      expect(activateCalled, isTrue);
      expect(identical(handles.appCheck, mockAppCheck), isTrue);
    });

    test('appCheck is null when enableAppCheck is false, and neither '
        'resolver nor activator is invoked', () async {
      var resolverCalled = false;
      var activatorCalled = false;
      final registry = buildRegistry(
        resolveAppCheck: (app) {
          resolverCalled = true;
          return MockFirebaseAppCheckHandle();
        },
        activateAppCheck: (appCheck) async {
          activatorCalled = true;
        },
      );

      final handles = await registry.resolve('acc-1');

      expect(handles.appCheck, isNull);
      expect(resolverCalled, isFalse);
      expect(activatorCalled, isFalse);
    });

    test(
      'an App Check activation failure is swallowed (non-fatal): resolve() '
      'still succeeds with a null appCheck handle and a warning is logged',
      () async {
        final talker = Talker();
        final logger = AppLogger(talker);
        final registry = buildRegistry(
          enableAppCheck: true,
          logger: logger,
          resolveAppCheck: (app) => MockFirebaseAppCheckHandle(),
          activateAppCheck: (appCheck) async {
            throw Exception('attestation unavailable');
          },
        );

        final handles = await registry.resolve('acc-1');

        expect(handles.appCheck, isNull);
        // Firestore/Auth handles are unaffected by the App Check failure.
        expect(handles.firestore, isNotNull);
        expect(handles.auth, isNotNull);
        expect(
          talker.history.any(
            (e) => e.generateTextMessage().contains(
              'account_firebase_app_check_activation_failed',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}
