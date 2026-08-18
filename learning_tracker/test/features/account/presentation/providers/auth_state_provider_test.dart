// Regression test for AUD-account-19 (AU-4):
//
// auth_providers.dart defines a genuinely stream-backed, reactive Firebase
// auth-state primitive (now `firebaseAuthStateProvider`) — but the provider
// that actually drove session routing everywhere (AuthGuard, AppShell,
// screens) was the differently-implemented, identically-named
// `authStateProvider` generated from `AuthStateNotifier`, which never
// watched or listened to that stream. If Firebase invalidated a session
// server-side (disabled account, revoked refresh token, forced sign-out
// elsewhere) while the app was running, nothing re-derived
// `AuthStateNotifier`'s state from that change — the app kept believing the
// user was signed in until an unrelated explicit action happened to call
// reload/signOut.
//
// Fix: `AuthStateNotifier.build()` now `ref.listen`s the raw Firebase stream
// and transitions a signed-in cloud-born session to signedOut when the
// stream settles to null — WITHOUT this test ever calling
// `AuthStateNotifier.signOut()` or `AuthRepository.signOut()` itself. The
// two providers also no longer share the `authStateProvider` name (the raw
// stream was renamed to `firebaseAuthStateProvider`), so this test exercises
// the real, unaliased providers.

@Tags(['unit', 'account', 'auth'])
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../mocks/mock_repositories.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'fb-uid-live-session';

AppUser _cloudUser() => const AppUser(
  uid: _uid,
  email: 'live@example.test',
  displayName: 'Live Session',
  emailVerified: true,
  providers: ['google.com'],
);

void main() {
  late MockAuthRepository auth;
  late StreamController<AppUser?> sessionController;
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedAccount(
      firestore,
      uid: _uid,
      email: 'live@example.test',
      displayName: 'Live Session',
    );

    auth = MockAuthRepository();
    sessionController = StreamController<AppUser?>.broadcast();

    when(() => auth.currentUser).thenReturn(_cloudUser());
    when(() => auth.reloadCurrentUser()).thenAnswer((_) async => _cloudUser());
    when(
      () => auth.onAuthStateChanged(),
    ).thenAnswer((_) => sessionController.stream);
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await sessionController.close();
  });

  test(
    'AuthStateNotifier transitions signedIn cloud-born -> signedOut when the '
    'live Firebase stream settles to null, with no explicit signOut() call',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => AccountFirebaseHandles(
              app: _MockFirebaseApp(),
              firestore: firestore,
              auth: _MockFirebaseAuth(),
              uid: _uid,
            ),
          ),
          firestoreAccountRepositoryProvider.overrideWith(
            (ref) async =>
                FirestoreAccountRepository(firestore: firestore, uid: _uid),
          ),
        ],
      );
      addTearDown(container.dispose);

      final states = <AuthState>[];
      container.listen<AuthState>(authStateProvider, (_, next) {
        states.add(next);
      }, fireImmediately: true);

      // Let AuthStateNotifier._init() resolve from Firebase's currentUser +
      // the seeded cloud-born profile row.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        container.read(authStateProvider).isSignedIn,
        isTrue,
        reason: '_init() should have resolved the seeded cloud-born session',
      );
      expect(container.read(authStateProvider).isCloudBorn, isTrue);

      // The device's live Firebase session becomes unauthenticated —
      // server-side revocation, disabled account, forced sign-out elsewhere.
      // Nothing in THIS test calls AuthRepository.signOut() or
      // AuthStateNotifier.signOut() — the only input is the stream emission.
      sessionController.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        container.read(authStateProvider).isSignedIn,
        isFalse,
        reason:
            'AUD-account-19: AuthStateNotifier must react to a live Firebase '
            'session invalidation it did not itself cause, by watching the '
            'auth-state stream instead of staying frozen at the last '
            'explicit state transition.',
      );

      // Confirm the transition happened via the reactive listener, not via
      // this app calling signOut() anywhere.
      verifyNever(() => auth.signOut());
    },
  );

  test('AuthStateNotifier ignores a non-null stream emission (no duplicate '
      're-derivation of an already-active session)', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => AccountFirebaseHandles(
            app: _MockFirebaseApp(),
            firestore: firestore,
            auth: _MockFirebaseAuth(),
            uid: _uid,
          ),
        ),
        firestoreAccountRepositoryProvider.overrideWith(
          (ref) async =>
              FirestoreAccountRepository(firestore: firestore, uid: _uid),
        ),
      ],
    );
    addTearDown(container.dispose);

    final states = <AuthState>[];
    container.listen<AuthState>(authStateProvider, (_, next) {
      states.add(next);
    }, fireImmediately: true);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(container.read(authStateProvider).isSignedIn, isTrue);
    final stateCountBeforeEmission = states.length;

    // A non-null emission (e.g. a token refresh reconfirming the SAME
    // identity) must not trigger a redundant state re-derivation — every
    // path that authenticates to a genuinely NEW identity already drives
    // this notifier directly (setCloudBornSession/setLocalBornSession).
    sessionController.add(_cloudUser());
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      states.length,
      stateCountBeforeEmission,
      reason:
          'a non-null stream emission must not produce an extra state '
          'transition — only a null (session-invalidated) emission does',
    );
    expect(container.read(authStateProvider).isSignedIn, isTrue);
  });
}
