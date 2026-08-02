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

// AUD-core-sync-20-style exception (see
// `test/core/sync/firestore_gateway_impl_test.dart`'s identical marker):
// the defect #3 post-dispose-read red-demo below implements cloud_firestore's
// `@sealed`-annotated `CollectionReference`/`Query` to make a fake that
// actually enforces the real SDK's post-`terminate()` throwing contract — a
// deliberate, narrow, test-only exception to the "don't implement sealed
// classes" guidance.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

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
    when(() => mock.terminate()).thenAnswer((_) async {});
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

  // ── Defect #4: the ≤maxAccounts bound must count in-flight resolves too ──

  group('resolve — bound counts in-flight resolves, not just settled ones '
      '(defect #4 red-demo)', () {
    test('N concurrent resolve() calls for N DISTINCT new account ids are '
        'bounded by the combined settled+in-flight count — a bound check '
        'against `_handles.length` alone (pre-fix) sees every one of them as '
        '0 settled accounts and lets all N through', () async {
      final releaseInit = Completer<void>();
      final initCalls = <String>[];

      final registry = AccountFirebase(
        options: _options,
        maxAccounts: 2,
        enableAppCheck: false,
        initializeApp:
            ({required String name, required FirebaseOptions options}) async {
              initCalls.add(name);
              // Held open so every concurrent resolve() below is still
              // in-flight (nothing has settled into `_handles` yet) at
              // the moment the THIRD resolve's bound check runs.
              await releaseInit.future;
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
        deleteApp: (app) async {},
      );

      // Fired back-to-back with no await between them: all three
      // synchronous prefixes (including each one's own settled/pending
      // check and, for the first two, the `_pending[id] = future`
      // assignment) run before any of them reaches `releaseInit.future`.
      final a = registry.resolve('acc-a');
      final b = registry.resolve('acc-b');
      final c = registry.resolve('acc-c');

      // Bounded: pre-fix, `c` never throws at all — it silently proceeds
      // past a bound check that only ever sees `_handles.length == 0` and
      // then blocks forever on `releaseInit.future` (which this test only
      // completes AFTER expecting the throw). Without this timeout that
      // regression hangs for the full test-runner timeout (2 minutes)
      // instead of failing fast.
      await expectLater(
        c,
        throwsA(isA<MaxAccountsReachedException>()),
      ).timeout(const Duration(seconds: 5));
      expect(
        initCalls,
        ['account_acc-a', 'account_acc-b'],
        reason:
            'the third, over-the-bound account must never reach '
            'initializeApp at all',
      );

      releaseInit.complete();
      await Future.wait([a, b]);
      expect(registry.activeAccountIds, {'acc-a', 'acc-b'});
    });
  });

  // ── Defect #2: resolve() racing an in-flight dispose() of the SAME id ────

  group('resolve — waits out an in-flight dispose() of the SAME account '
      '(defect #2 red-demo)', () {
    test('a resolve() issued while this SAME account is still natively listed '
        'but mid-deletion (the real SDK keeps a deleting app in Firebase.apps '
        'until app.delete() actually returns) waits for the teardown to '
        'finish, then creates a genuinely NEW app — it must never reuse the '
        'still-listed, about-to-be-deleted one', () async {
      final initCalls = <String>[];
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      final apps = <String, MockFirebaseApp>{};
      // Mirrors `Firebase.apps`: only removed once the fake `deleteApp`
      // call actually finishes, matching
      // `MethodChannelFirebaseApp.delete()`'s real ordering.
      final nativeAppNames = <String>{};

      final registry = AccountFirebase(
        options: _options,
        enableAppCheck: false,
        initializeApp:
            ({required String name, required FirebaseOptions options}) async {
              initCalls.add(name);
              final app = MockFirebaseApp();
              when(() => app.name).thenReturn(name);
              apps[name] = app;
              nativeAppNames.add(name);
              return app;
            },
        listApps: () => [for (final n in nativeAppNames) apps[n]!],
        resolveFirestore: (app) {
          final mock = MockFirebaseFirestore();
          when(() => mock.terminate()).thenAnswer((_) async {});
          return mock;
        },
        resolveAuth: (app) => MockFirebaseAuthHandle(),
        deleteApp: (app) async {
          deleteStarted.complete();
          await releaseDelete.future;
          nativeAppNames.remove(app.name);
        },
      );

      final first = await registry.resolve('acc-race');

      final disposeFuture = registry.dispose('acc-race');
      await deleteStarted.future;
      // The fake native delete() call is deliberately being held open
      // right now — exactly the SDK's documented deleting-but-still-
      // listed window.
      expect(nativeAppNames, contains('account_acc-race'));

      // A concurrent resolve() for the SAME account, issued WHILE it is
      // still natively listed but mid-deletion.
      final resolveDuringDispose = registry.resolve('acc-race');

      releaseDelete.complete();
      await disposeFuture;
      final second = await resolveDuringDispose;

      expect(
        initCalls,
        ['account_acc-race', 'account_acc-race'],
        reason:
            'a genuinely NEW native app must be created for the second '
            'resolve — pre-fix, _findOrInitializeApp scanned the '
            'still-listed (dying) app via listApps() and reused it, so '
            'initializeApp was only ever called once',
      );
      expect(
        identical(first.app, second.app),
        isFalse,
        reason:
            'the second resolve must not hand back the app that was '
            'being deleted out from under it',
      );
    });
  });

  // ── Defect #3: app.delete() alone does not release the Firestore handle ─

  group('dispose — releases the Firestore handle too, not just the app '
      '(defect #3 red-demo)', () {
    test('calls firestore.terminate() BEFORE app.delete(), and marks the '
        'handles bundle isDisposed', () async {
      final callOrder = <String>[];
      final registry = AccountFirebase(
        options: _options,
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
          when(() => mock.terminate()).thenAnswer((_) async {
            callOrder.add('terminate');
          });
          return mock;
        },
        resolveAuth: (app) => MockFirebaseAuthHandle(),
        deleteApp: (app) async {
          callOrder.add('delete');
        },
      );

      final handles = await registry.resolve('acc-1');
      expect(handles.isDisposed, isFalse);

      await registry.dispose('acc-1');

      expect(handles.isDisposed, isTrue);
      expect(
        callOrder,
        ['terminate', 'delete'],
        reason:
            'app.delete() alone does not release the cached '
            'FirebaseFirestore instance (no registerService hook) — '
            'terminate() must run first',
      );
    });

    test('a read issued through the disposed handles.firestore fails instead '
        'of silently succeeding against a deleted app — the exact per-switch '
        'sequence Phase 2 repository code will perform, and the shape the '
        '"third-party plugin bug" '
        '(integration_test/account_firebase_multi_account_test.dart) symptom '
        '(b) traces back to', () async {
      final registry = AccountFirebase(
        options: _options,
        enableAppCheck: false,
        initializeApp:
            ({required String name, required FirebaseOptions options}) async {
              final app = MockFirebaseApp();
              when(() => app.name).thenReturn(name);
              return app;
            },
        listApps: () => const [],
        resolveFirestore: (app) => _TerminateEnforcingFirestore(),
        resolveAuth: (app) => MockFirebaseAuthHandle(),
        deleteApp: (app) async {},
      );

      final handles = await registry.resolve('acc-1');
      // Sanity: a read works fine before dispose.
      expect(() => handles.firestore.collection('probe'), returnsNormally);

      await registry.dispose('acc-1');

      expect(handles.isDisposed, isTrue);
      expect(
        () => handles.firestore.collection('probe'),
        throwsA(isA<FirebaseException>()),
        reason:
            'post-dispose, a Firestore read must fail loudly instead of '
            'silently talking to a deleted app',
      );
    });
  });
}

/// A Firestore fake that actually ENFORCES `cloud_firestore`'s real
/// `terminate()` contract ("After calling terminate() only the
/// clearPersistence() method may be used. Any other method will throw a
/// FirebaseException.") — unlike the bare `MockFirebaseFirestore` used
/// everywhere else in this file (which silently allows any stubbed call
/// regardless of dispose state, since mocktail's `Mock` doesn't model this
/// on its own). Used ONLY by the post-dispose-read test above.
class _TerminateEnforcingFirestore extends Mock implements FirebaseFirestore {
  bool _terminated = false;

  @override
  Future<void> terminate() async {
    _terminated = true;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (_terminated) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'The client has already been terminated.',
      );
    }
    return _FakeCollectionReference();
  }
}

/// A deliberate, narrow, test-only exception to the "don't implement sealed
/// classes" guidance (see this file's top-of-file `ignore_for_file`) —
/// mirrors `test/core/sync/firestore_gateway_impl_test.dart`'s
/// `_DenySetCollectionReference` (same rationale: a test proxy that needs
/// to BE a `CollectionReference`, not merely resemble one). Never actually
/// used past construction — this test only needs `collection()` to return
/// SOMETHING typed correctly before dispose, and the "read must fail"
/// assertion is entirely about the post-dispose CALL to `.collection` on
/// the wrapping [_TerminateEnforcingFirestore] itself, not this class.
class _FakeCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}
