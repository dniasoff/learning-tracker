/// Unit tests for the `AccountFirebase` registry,
/// `lib/data/firestore/account_firebase.dart`.
///
/// No platform binding, no device, no emulator: every native SDK entry
/// point the registry touches (`Firebase.initializeApp`, `Firebase.apps`,
/// `FirebaseFirestore.instanceFor`, `FirebaseAuth.instanceFor`,
/// `FirebaseApp.delete()`) is injected as a fake/mock per the class's
/// documented testability seam. `FirebaseAuth` itself is not sealed, so
/// every auth call (`currentUser`, `authStateChanges()`,
/// `signInAnonymously()`, `signInWithCredential()`,
/// `User.linkWithCredential()`, `signOut()`) is exercised by stubbing the
/// SAME `MockFirebaseAuthHandle` the injected [FirebaseAuthResolver] hands
/// back — no separate auth seam is needed. `mocktail`'s
/// `class MockX extends Mock implements X {}` pattern mirrors
/// `test/core/sync/firestore_instance_provider_test.dart` — `Mock`
/// overrides `noSuchMethod` and never calls the real SDK constructor, so
/// this is safe without `TestWidgetsFlutterBinding`/Firebase test setup.
///
/// [_AuthHarness] is this file's one non-obvious piece of machinery: a test
/// registers, via `willBuild(accountId, ...)`, exactly how the Auth mock for
/// an account's (about-to-be-created) named app should behave — BEFORE
/// calling the registry method that triggers its creation. This sidesteps
/// the chicken-and-egg problem of needing to stub a mock that does not
/// exist yet: `willBuild` is keyed by the account's deterministic,
/// pre-computable app name ([AccountFirebase.appNameForAccount]), and the
/// harness's `resolveAuth` implementation only builds the mock the first
/// time that app name is actually requested.
///
/// TQ-6: no wall clock, no I/O, no shared mutable global state between
/// tests (every test builds its own registry + fakes) — order-independent
/// under `--test-randomize-ordering-seed=random`.
library;

// AUD-core-sync-20-style exception (see
// `test/core/sync/firestore_gateway_impl_test.dart`'s identical marker):
// the post-dispose-read test below implements cloud_firestore's
// `@sealed`-annotated `CollectionReference` to make a fake that actually
// enforces the real SDK's post-`terminate()` throwing contract — a
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

class MockFirebaseAppCheckHandle extends Mock implements FirebaseAppCheck {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class FakeAuthCredential extends Fake implements AuthCredential {}

const _options = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'test-project',
);

MockUser _mockUser(String uid) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  return user;
}

MockUserCredential _mockCredential(User? user) {
  final credential = MockUserCredential();
  when(() => credential.user).thenReturn(user);
  return credential;
}

/// A never-authenticated Auth mock: `currentUser` is `null` and
/// `authStateChanges()` emits a single `null` — the shape of a brand-new
/// app with no persisted session. The safe default the harness falls back
/// to when a test has not registered a recipe for an app name.
MockFirebaseAuthHandle _neverAuthenticatedMock() {
  final mock = MockFirebaseAuthHandle();
  when(() => mock.currentUser).thenReturn(null);
  when(
    () => mock.authStateChanges(),
  ).thenAnswer((_) => Stream<User?>.value(null));
  return mock;
}

/// An Auth mock simulating a genuinely fresh app: `currentUser` starts
/// `null`, `signInAnonymously()` "signs in" [uid] and makes `currentUser`
/// reflect it from then on (mirroring the real SDK's contract that
/// `currentUser` is updated by the time `signInAnonymously()`'s future
/// completes), and `signOut()` clears it back to `null`.
MockFirebaseAuthHandle _anonSignInMock(String uid) {
  final mock = MockFirebaseAuthHandle();
  User? signedIn;
  when(() => mock.currentUser).thenAnswer((_) => signedIn);
  when(
    () => mock.authStateChanges(),
  ).thenAnswer((_) => Stream<User?>.value(signedIn));
  when(() => mock.signInAnonymously()).thenAnswer((_) async {
    final user = _mockUser(uid);
    signedIn = user;
    return _mockCredential(user);
  });
  when(() => mock.signOut()).thenAnswer((_) async {
    signedIn = null;
  });
  return mock;
}

// ─── Recording fakes (the testability seam) ────────────────────────────────

/// Fakes `Firebase.initializeApp`: hands back a fresh [MockFirebaseApp]
/// stubbed with the requested [name] and records every call, so tests can
/// assert exactly how many times (and with which names) the real SDK entry
/// point would have been hit.
class _RecordingAppInitializer {
  int callCount = 0;
  final List<String> names = [];

  Future<FirebaseApp> call({
    required String name,
    required FirebaseOptions options,
  }) async {
    callCount++;
    names.add(name);
    final app = MockFirebaseApp();
    when(() => app.name).thenReturn(name);
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

class _RecordingAppDeleter {
  int callCount = 0;
  final List<String> deletedAppNames = [];

  Future<void> call(FirebaseApp app) async {
    callCount++;
    deletedAppNames.add(app.name);
  }
}

/// See the library doc comment for the chicken-and-egg problem this solves.
/// A test calls [willBuild] with the account id it is about to establish a
/// session for and a factory describing that account's Auth mock; the
/// harness only invokes the factory the first time [AccountFirebase] asks
/// for that app's Auth instance (i.e. never again after the underlying
/// [_AppSession] is cached — matching production, where `resolveAuth` is
/// only called once per account for the life of its session).
class _AuthHarness {
  final Map<String, MockFirebaseAuthHandle> created = {};
  final Map<String, MockFirebaseAuthHandle Function()> _recipes = {};

  void willBuild(String accountId, MockFirebaseAuthHandle Function() build) {
    _recipes[AccountFirebase.appNameForAccount(accountId)] = build;
  }

  MockFirebaseAuthHandle mockFor(String accountId) =>
      created[AccountFirebase.appNameForAccount(accountId)]!;

  FirebaseAuth call(FirebaseApp app) {
    final build = _recipes[app.name];
    final mock = build != null ? build() : _neverAuthenticatedMock();
    created[app.name] = mock;
    return mock;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Settings());
    registerFallbackValue(FakeAuthCredential());
  });

  late _RecordingAppInitializer initializeApp;
  late _RecordingFirestoreResolver resolveFirestore;
  late _RecordingAppDeleter deleteApp;

  AccountFirebase buildRegistry({
    int maxAccounts = 5,
    FirebaseAppsLister? listApps,
    _AuthHarness? authHarness,
    bool enableAppCheck = false,
    AppCheckResolver? resolveAppCheck,
    AppCheckActivator? activateAppCheck,
    AppLogger? logger,
    AccountSessionHook? onSessionCreated,
  }) {
    return AccountFirebase(
      options: _options,
      maxAccounts: maxAccounts,
      initializeApp: initializeApp.call,
      listApps: listApps ?? () => const [],
      resolveFirestore: resolveFirestore.call,
      resolveAuth: (authHarness ?? _AuthHarness()).call,
      deleteApp: deleteApp.call,
      enableAppCheck: enableAppCheck,
      resolveAppCheck: resolveAppCheck,
      activateAppCheck: activateAppCheck,
      logger: logger ?? AppLogger(Talker()),
      onSessionCreated: onSessionCreated,
    );
  }

  setUp(() {
    initializeApp = _RecordingAppInitializer();
    resolveFirestore = _RecordingFirestoreResolver();
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

  // ── createAnonymousAccount: the network-requiring creation path ─────────

  group(
    'createAnonymousAccount — creates the app and signs in anonymously',
    () {
      test('a resolved handle is authenticated: it carries the signed-in uid, '
          'and .settings was pinned bounded/non-unlimited before it was '
          'returned', () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
        final registry = buildRegistry(authHarness: auth);

        final handles = await registry.createAnonymousAccount('acc-1');

        expect(handles.uid, 'uid-1');
        expect(handles.app.name, 'account_acc-1');
        expect(identical(handles.auth, auth.mockFor('acc-1')), isTrue);

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
        );
      });

      test('two different accounts each get their own named app AND their '
          'own distinct auth session/uid', () async {
        final auth = _AuthHarness()
          ..willBuild('acc-a', () => _anonSignInMock('uid-a'))
          ..willBuild('acc-b', () => _anonSignInMock('uid-b'));
        final registry = buildRegistry(authHarness: auth);

        final a = await registry.createAnonymousAccount('acc-a');
        final b = await registry.createAnonymousAccount('acc-b');

        expect(initializeApp.callCount, 2);
        expect(a.app.name, isNot(equals(b.app.name)));
        expect(a.uid, isNot(equals(b.uid)));
        expect(registry.activeAccountIds, {'acc-a', 'acc-b'});
      });

      test('a second call for the same account, once already authenticated, '
          'is idempotent: no second signInAnonymously, same cached handles '
          'returned', () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
        final registry = buildRegistry(authHarness: auth);

        final first = await registry.createAnonymousAccount('acc-1');
        final second = await registry.createAnonymousAccount('acc-1');

        expect(identical(first, second), isTrue);
        verify(() => auth.mockFor('acc-1').signInAnonymously()).called(1);
      });

      test('creation surfaces a clear failure when anonymous sign-in fails (no '
          'network): the original exception propagates unwrapped, the account '
          'is not left authenticated, and its (locally-created) app is still '
          'there for a retry', () async {
        final failure = FirebaseAuthException(code: 'network-request-failed');
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(null);
            when(() => mock.signInAnonymously()).thenThrow(failure);
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);

        await expectLater(
          registry.createAnonymousAccount('acc-1'),
          throwsA(same(failure)),
        );

        expect(registry.isActive('acc-1'), isFalse);
        expect(
          registry.activeAccountIds,
          {'acc-1'},
          reason:
              'app creation is local and always succeeds — only the '
              'network RPC failed, so the app is still there to retry or '
              'dispose',
        );
        expect(initializeApp.callCount, 1);

        // Retrying reuses the SAME app rather than leaking a second one.
        final mock = auth.mockFor('acc-1');
        when(
          () => mock.signInAnonymously(),
        ).thenAnswer((_) async => _mockCredential(_mockUser('uid-1')));

        final handles = await registry.createAnonymousAccount('acc-1');
        expect(handles.uid, 'uid-1');
        expect(initializeApp.callCount, 1);
      });

      test('signInAnonymously() returning a null user is a clear StateError, '
          'not a silently-null uid', () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(null);
            when(
              () => mock.signInAnonymously(),
            ).thenAnswer((_) async => _mockCredential(null));
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);

        await expectLater(
          registry.createAnonymousAccount('acc-1'),
          throwsA(isA<StateError>()),
        );
      });
    },
  );

  // ── resolve: re-attaches, never signs in itself ──────────────────────────

  group('resolve — re-attaches to an already-authenticated session, never '
      'signs in itself', () {
    test('throws AccountNotAuthenticatedException when the account was '
        'never created (no persisted session to restore)', () async {
      final registry = buildRegistry();

      await expectLater(
        registry.resolve('never-created'),
        throwsA(isA<AccountNotAuthenticatedException>()),
      );
    });

    test(
      'when the persisted session is already restored (currentUser '
      'non-null the instant Auth is resolved), resolve returns an '
      'authenticated handle without ever touching authStateChanges',
      () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            final restoredUser = _mockUser('uid-restored');
            when(() => mock.currentUser).thenReturn(restoredUser);
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);

        final handles = await registry.resolve('acc-1');

        expect(handles.uid, 'uid-restored');
        verifyNever(() => auth.mockFor('acc-1').authStateChanges());
      },
    );

    test('when currentUser is null right after Auth is resolved but the '
        'restore completes asynchronously (authStateChanges fires with a '
        'non-null user), resolve waits for it', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () {
          final mock = MockFirebaseAuthHandle();
          when(() => mock.currentUser).thenReturn(null);
          when(() => mock.authStateChanges()).thenAnswer(
            (_) => Stream<User?>.value(_mockUser('uid-async-restored')),
          );
          return mock;
        });
      final registry = buildRegistry(authHarness: auth);

      final handles = await registry.resolve('acc-1');

      expect(handles.uid, 'uid-async-restored');
    });

    test('a reattach failure cannot short-circuit a concurrent authenticating '
        'call for the same account', () async {
      final authState = StreamController<User?>();
      final resolveStarted = Completer<void>();
      final cloudUser = _mockUser('uid-cloud');
      final auth = _AuthHarness()
        ..willBuild('acc-race', () {
          final mock = MockFirebaseAuthHandle();
          User? currentUser;
          when(() => mock.currentUser).thenAnswer((_) => currentUser);
          when(() => mock.authStateChanges()).thenAnswer((_) {
            if (!resolveStarted.isCompleted) resolveStarted.complete();
            return authState.stream;
          });
          when(() => mock.signInWithCredential(any())).thenAnswer((_) async {
            currentUser = cloudUser;
            return _mockCredential(cloudUser);
          });
          return mock;
        });
      final registry = buildRegistry(authHarness: auth);

      final reattach = registry.resolve('acc-race');
      await resolveStarted.future;

      final authenticate = registry.signInCloudAccount(
        'acc-race',
        FakeAuthCredential(),
      );
      final handles = await authenticate;

      expect(handles.uid, 'uid-cloud');
      verify(
        () => auth.mockFor('acc-race').signInWithCredential(any()),
      ).called(1);

      // Let the intentionally unauthenticated reattach path settle after
      // the authenticating path has independently succeeded.
      authState.add(null);
      await expectLater(
        reattach,
        throwsA(isA<AccountNotAuthenticatedException>()),
      );
      await authState.close();
    });

    test('a second resolve() for the same already-resolved account does NOT '
        'call initializeApp again and returns the identical handles', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () {
          final mock = MockFirebaseAuthHandle();
          final currentUser = _mockUser('uid-1');
          when(() => mock.currentUser).thenReturn(currentUser);
          return mock;
        });
      final registry = buildRegistry(authHarness: auth);

      final first = await registry.resolve('acc-1');
      final second = await registry.resolve('acc-1');

      expect(initializeApp.callCount, 1);
      expect(identical(first, second), isTrue);
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
      final auth = _AuthHarness()
        ..willBuild('acc-1', () {
          final mock = MockFirebaseAuthHandle();
          final currentUser = _mockUser('uid-1');
          when(() => mock.currentUser).thenReturn(currentUser);
          return mock;
        });
      final registry = buildRegistry(
        listApps: () => [existingApp],
        authHarness: auth,
      );

      final handles = await registry.resolve('acc-1');

      expect(initializeApp.callCount, 0);
      expect(identical(handles.app, existingApp), isTrue);
    });
  });

  // ── linkCredential: Upgrade-to-Cloud preserves the uid ───────────────────

  group('linkCredential — Upgrade-to-Cloud preserves the uid (no data '
      'migration)', () {
    test(
      'links onto the currently signed-in user and returns the SAME uid',
      () async {
        final signedInUser = _mockUser('uid-anon');
        final linkedCredential = _mockCredential(_mockUser('uid-anon'));
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(signedInUser);
            when(
              () => signedInUser.linkWithCredential(any()),
            ).thenAnswer((_) async => linkedCredential);
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);

        final original = await registry.createAnonymousAccount('acc-1');
        expect(original.uid, 'uid-anon');

        final credential = FakeAuthCredential();
        final updated = await registry.linkCredential('acc-1', credential);

        verify(() => signedInUser.linkWithCredential(credential)).called(1);
        expect(updated.uid, 'uid-anon');
        expect(updated.uid, original.uid, reason: 'uid must never change');
        expect(identical(updated.app, original.app), isTrue);
        expect(identical(updated.auth, original.auth), isTrue);
      },
    );

    test('throws StateError if the account has never been resolved', () async {
      final registry = buildRegistry();

      await expectLater(
        registry.linkCredential('never-resolved', FakeAuthCredential()),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'linkWithCredential() returning a null user is a clear StateError',
      () async {
        final signedInUser = _mockUser('uid-anon');
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(signedInUser);
            when(
              () => signedInUser.linkWithCredential(any()),
            ).thenAnswer((_) async => _mockCredential(null));
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);
        await registry.createAnonymousAccount('acc-1');

        await expectLater(
          registry.linkCredential('acc-1', FakeAuthCredential()),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  // ── signInCloudAccount: signs in with a credential on the account's own
  //    named app ──────────────────────────────────────────────────────────

  group("signInCloudAccount — signs in with a credential on the account's "
      'own named app', () {
    test(
      'returns an authenticated handle carrying the credential uid',
      () async {
        final credential = FakeAuthCredential();
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(null);
            when(
              () => mock.signInWithCredential(any()),
            ).thenAnswer((_) async => _mockCredential(_mockUser('uid-cloud')));
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);

        final handles = await registry.signInCloudAccount('acc-1', credential);

        expect(handles.uid, 'uid-cloud');
        verify(
          () => auth.mockFor('acc-1').signInWithCredential(credential),
        ).called(1);
      },
    );

    test(
      'signInWithCredential() returning a null user is a clear StateError',
      () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(null);
            when(
              () => mock.signInWithCredential(any()),
            ).thenAnswer((_) async => _mockCredential(null));
            return mock;
          });
        final registry = buildRegistry(authHarness: auth);

        await expectLater(
          registry.signInCloudAccount('acc-1', FakeAuthCredential()),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  // ── Bound to ≤ maxAccounts, fails loudly ──────────────────────────────────

  group('bounded account count fails loudly, never evicts', () {
    test(
      'creating a NEW account past maxAccounts throws '
      'MaxAccountsReachedException and does not touch initializeApp',
      () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () => _anonSignInMock('uid-1'))
          ..willBuild('acc-2', () => _anonSignInMock('uid-2'));
        final registry = buildRegistry(maxAccounts: 2, authHarness: auth);
        await registry.createAnonymousAccount('acc-1');
        await registry.createAnonymousAccount('acc-2');
        expect(initializeApp.callCount, 2);

        await expectLater(
          registry.createAnonymousAccount('acc-3'),
          throwsA(isA<MaxAccountsReachedException>()),
        );

        expect(initializeApp.callCount, 2);
        expect(registry.activeAccountIds, {'acc-1', 'acc-2'});
      },
    );

    test('re-establishing an already-active account at the bound is '
        'allowed (idempotent, not itself growth)', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(maxAccounts: 1, authHarness: auth);
      final first = await registry.createAnonymousAccount('acc-1');

      final second = await registry.createAnonymousAccount('acc-1');

      expect(identical(first, second), isTrue);
      expect(initializeApp.callCount, 1);
    });

    test('re-authenticating after signOut at the bound is allowed — the '
        'session/app already counts against the bound; signOut does not '
        'free a slot', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(maxAccounts: 1, authHarness: auth);
      await registry.createAnonymousAccount('acc-1');

      await registry.signOut('acc-1');
      expect(registry.isActive('acc-1'), isFalse);
      expect(registry.activeAccountIds, {'acc-1'});

      final rebuilt = await registry.createAnonymousAccount('acc-1');

      expect(
        rebuilt.uid,
        'uid-1',
        reason: '_anonSignInMock re-signs-in the same uid',
      );
      expect(initializeApp.callCount, 1, reason: 'must reuse the same app');
    });

    test('constructor rejects a non-positive maxAccounts', () {
      expect(
        () => AccountFirebase(options: _options, maxAccounts: 0),
        throwsArgumentError,
      );
    });
  });

  // ── signOut: clears the auth session, keeps the app/cache alive ─────────

  group('signOut — clears the Auth session without tearing the app down', () {
    test(
      'after signOut, isActive is false but the app/session stays live '
      '(activeAccountIds still counts it) and deleteApp is never called',
      () async {
        final auth = _AuthHarness()
          ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
        final registry = buildRegistry(authHarness: auth);
        await registry.createAnonymousAccount('acc-1');

        await registry.signOut('acc-1');

        verify(() => auth.mockFor('acc-1').signOut()).called(1);
        expect(registry.isActive('acc-1'), isFalse);
        expect(registry.activeAccountIds, {'acc-1'});
        expect(deleteApp.callCount, 0);
      },
    );

    test('is a safe no-op for an account with no active session', () async {
      final registry = buildRegistry();
      await registry.signOut('never-resolved');
      expect(deleteApp.callCount, 0);
    });

    test('resolve() after signOut throws AccountNotAuthenticatedException '
        '— never silently hands back the stale authenticated bundle', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(authHarness: auth);
      await registry.createAnonymousAccount('acc-1');

      await registry.signOut('acc-1');

      await expectLater(
        registry.resolve('acc-1'),
        throwsA(isA<AccountNotAuthenticatedException>()),
      );
      expect(initializeApp.callCount, 1, reason: 'must not re-init the app');
    });
  });

  // ── App Check: activated per named app, best-effort, non-fatal ──────────

  group('session establishment — App Check is activated per named app, '
      'best-effort and non-fatal', () {
    test('resolves and activates App Check when enabled, before the '
        'account signs in', () async {
      final mockAppCheck = MockFirebaseAppCheckHandle();
      var activateCalled = false;
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(
        authHarness: auth,
        enableAppCheck: true,
        resolveAppCheck: (app) => mockAppCheck,
        activateAppCheck: (appCheck) async {
          activateCalled = true;
          expect(identical(appCheck, mockAppCheck), isTrue);
        },
      );

      final handles = await registry.createAnonymousAccount('acc-1');

      expect(activateCalled, isTrue);
      expect(identical(handles.appCheck, mockAppCheck), isTrue);
    });

    test('appCheck is null when enableAppCheck is false (this file\'s '
        'default), and neither resolver nor activator is invoked', () async {
      var resolverCalled = false;
      var activatorCalled = false;
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(
        authHarness: auth,
        resolveAppCheck: (app) {
          resolverCalled = true;
          return MockFirebaseAppCheckHandle();
        },
        activateAppCheck: (appCheck) async {
          activatorCalled = true;
        },
      );

      final handles = await registry.createAnonymousAccount('acc-1');

      expect(handles.appCheck, isNull);
      expect(resolverCalled, isFalse);
      expect(activatorCalled, isFalse);
    });

    test(
      'an App Check activation failure is swallowed (non-fatal): account '
      'creation still succeeds with a null appCheck handle and a warning '
      'is logged — mirrors firebase_bootstrap.dart\'s default-app treatment',
      () async {
        final talker = Talker();
        final logger = AppLogger(talker);
        final auth = _AuthHarness()
          ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
        final registry = buildRegistry(
          authHarness: auth,
          enableAppCheck: true,
          logger: logger,
          resolveAppCheck: (app) => MockFirebaseAppCheckHandle(),
          activateAppCheck: (appCheck) async {
            throw Exception('attestation unavailable');
          },
        );

        final handles = await registry.createAnonymousAccount('acc-1');

        expect(handles.appCheck, isNull);
        // Firestore/Auth/the account's uid are unaffected by the App
        // Check failure — creation is not blocked by it.
        expect(handles.firestore, isNotNull);
        expect(handles.uid, 'uid-1');
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

    test('App Check is activated exactly once per account, not re-activated '
        'on a later signOut/re-authenticate cycle', () async {
      var activateCallCount = 0;
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(
        authHarness: auth,
        enableAppCheck: true,
        resolveAppCheck: (app) => MockFirebaseAppCheckHandle(),
        activateAppCheck: (appCheck) async {
          activateCallCount++;
        },
      );

      await registry.createAnonymousAccount('acc-1');
      await registry.signOut('acc-1');
      await registry.createAnonymousAccount('acc-1');

      expect(activateCallCount, 1);
    });
  });

  // ── onSessionCreated: the test-only pre-auth emulator-redirection seam ──

  group('onSessionCreated — runs once per account, after the app/firestore/'
      'auth/App-Check wiring exists but strictly before the first sign-in', () {
    test('runs before signInAnonymously and receives the same app/firestore'
        '/auth instances the returned handles carry', () async {
      final callOrder = <String>[];
      final auth = _AuthHarness()
        ..willBuild('acc-1', () {
          final mock = MockFirebaseAuthHandle();
          User? signedIn;
          when(() => mock.currentUser).thenAnswer((_) => signedIn);
          when(() => mock.signInAnonymously()).thenAnswer((_) async {
            callOrder.add('signInAnonymously');
            final user = _mockUser('uid-1');
            signedIn = user;
            return _mockCredential(user);
          });
          return mock;
        });
      FirebaseApp? hookApp;
      FirebaseFirestore? hookFirestore;
      FirebaseAuth? hookAuth;
      final registry = buildRegistry(
        authHarness: auth,
        onSessionCreated: (app, firestore, auth) async {
          callOrder.add('onSessionCreated');
          hookApp = app;
          hookFirestore = firestore;
          hookAuth = auth;
        },
      );

      final handles = await registry.createAnonymousAccount('acc-1');

      expect(callOrder, ['onSessionCreated', 'signInAnonymously']);
      expect(identical(hookApp, handles.app), isTrue);
      expect(identical(hookFirestore, handles.firestore), isTrue);
      expect(identical(hookAuth, handles.auth), isTrue);
    });

    test('runs exactly once per account — not re-run on a later signOut/'
        're-authenticate cycle', () async {
      var hookCallCount = 0;
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(
        authHarness: auth,
        onSessionCreated: (app, firestore, auth) async {
          hookCallCount++;
        },
      );

      await registry.createAnonymousAccount('acc-1');
      await registry.signOut('acc-1');
      await registry.createAnonymousAccount('acc-1');

      expect(hookCallCount, 1);
    });

    test('defaults to null (no-op) — a registry built without one behaves '
        'exactly as before', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(authHarness: auth);

      final handles = await registry.createAnonymousAccount('acc-1');

      expect(handles.uid, 'uid-1');
    });
  });

  // ── dispose(): genuinely complete, testably so ───────────────────────────

  group('dispose — releases the app and is safe to re-create afterwards', () {
    test('deletes the app exactly once and clears active state', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(authHarness: auth);
      await registry.createAnonymousAccount('acc-1');

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
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(authHarness: auth);
      await registry.createAnonymousAccount('acc-1');

      await registry.dispose('acc-1');
      await registry.dispose('acc-1');

      expect(deleteApp.callCount, 1);
    });

    test('dispose-then-resolve creates a genuinely NEW app (proves the old '
        'handle was actually released, not just hidden)', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'));
      final registry = buildRegistry(authHarness: auth);
      final before = await registry.createAnonymousAccount('acc-1');

      await registry.dispose('acc-1');
      auth.willBuild('acc-1', () => _anonSignInMock('uid-1-again'));
      final after = await registry.createAnonymousAccount('acc-1');

      expect(initializeApp.callCount, 2);
      expect(identical(before, after), isFalse);
      expect(identical(before.app, after.app), isFalse);
      expect(registry.isActive('acc-1'), isTrue);
    });

    test('disposeAll tears down every active account', () async {
      final auth = _AuthHarness()
        ..willBuild('acc-1', () => _anonSignInMock('uid-1'))
        ..willBuild('acc-2', () => _anonSignInMock('uid-2'))
        ..willBuild('acc-3', () => _anonSignInMock('uid-3'));
      final registry = buildRegistry(authHarness: auth);
      await registry.createAnonymousAccount('acc-1');
      await registry.createAnonymousAccount('acc-2');
      await registry.createAnonymousAccount('acc-3');

      await registry.disposeAll();

      expect(deleteApp.callCount, 3);
      expect(registry.activeAccountIds, isEmpty);
    });

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
        resolveAuth: (app) {
          final mock = MockFirebaseAuthHandle();
          final currentUser = _mockUser('uid-1');
          when(() => mock.currentUser).thenReturn(currentUser);
          return mock;
        },
        deleteApp: (app) async {
          callOrder.add('delete');
        },
      );

      final handles = await registry.resolve('acc-1');
      expect(handles.isDisposed, isFalse);

      await registry.dispose('acc-1');

      expect(handles.isDisposed, isTrue);
      expect(callOrder, ['terminate', 'delete']);
    });

    test('a read issued through the disposed handles.firestore fails instead '
        'of silently succeeding against a deleted app', () async {
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
        resolveAuth: (app) {
          final mock = MockFirebaseAuthHandle();
          final currentUser = _mockUser('uid-1');
          when(() => mock.currentUser).thenReturn(currentUser);
          return mock;
        },
        deleteApp: (app) async {},
      );

      final handles = await registry.resolve('acc-1');
      expect(() => handles.firestore.collection('probe'), returnsNormally);

      await registry.dispose('acc-1');

      expect(handles.isDisposed, isTrue);
      expect(
        () => handles.firestore.collection('probe'),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  // ── the ≤maxAccounts bound must count in-flight establishments too ──────

  group('bound counts in-flight establishments, not just settled ones', () {
    test(
      'N concurrent createAnonymousAccount() calls for N DISTINCT new '
      'account ids are bounded by the combined settled+in-flight count',
      () async {
        final releaseInit = Completer<void>();
        final initCalls = <String>[];

        final registry = AccountFirebase(
          options: _options,
          enableAppCheck: false,
          maxAccounts: 2,
          initializeApp:
              ({required String name, required FirebaseOptions options}) async {
                initCalls.add(name);
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
          resolveAuth: (app) {
            final mock = MockFirebaseAuthHandle();
            when(() => mock.currentUser).thenReturn(null);
            when(() => mock.signInAnonymously()).thenAnswer(
              (_) async => _mockCredential(_mockUser('uid-${app.name}')),
            );
            return mock;
          },
          deleteApp: (app) async {},
        );

        final a = registry.createAnonymousAccount('acc-a');
        final b = registry.createAnonymousAccount('acc-b');
        final c = registry.createAnonymousAccount('acc-c');

        await expectLater(
          c,
          throwsA(isA<MaxAccountsReachedException>()),
        ).timeout(const Duration(seconds: 5));
        expect(initCalls, ['account_acc-a', 'account_acc-b']);

        releaseInit.complete();
        await Future.wait([a, b]);
        expect(registry.activeAccountIds, {'acc-a', 'acc-b'});
      },
    );
  });

  // ── resolve() racing an in-flight dispose() of the SAME id ───────────────

  group('resolve — waits out an in-flight dispose() of the SAME account', () {
    test('a resolve() issued while this SAME account is still natively '
        'listed but mid-deletion waits for the teardown to finish, then '
        'creates a genuinely NEW app', () async {
      final initCalls = <String>[];
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      final apps = <String, MockFirebaseApp>{};
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
        resolveAuth: (app) {
          final mock = MockFirebaseAuthHandle();
          final currentUser = _mockUser('uid-race');
          when(() => mock.currentUser).thenReturn(currentUser);
          return mock;
        },
        deleteApp: (app) async {
          deleteStarted.complete();
          await releaseDelete.future;
          nativeAppNames.remove(app.name);
        },
      );

      final first = await registry.resolve('acc-race');

      final disposeFuture = registry.dispose('acc-race');
      await deleteStarted.future;
      expect(nativeAppNames, contains('account_acc-race'));

      final resolveDuringDispose = registry.resolve('acc-race');

      releaseDelete.complete();
      await disposeFuture;
      final second = await resolveDuringDispose;

      expect(initCalls, ['account_acc-race', 'account_acc-race']);
      expect(identical(first.app, second.app), isFalse);
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
/// classes" guidance (see this file's top-of-file `ignore_for_file`).
class _FakeCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}
