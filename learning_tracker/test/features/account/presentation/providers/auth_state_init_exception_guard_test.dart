// Regression tests for AUD-account-03 / AUD-account-11:
//
// AuthStateNotifier.build() kicks off _init() fire-and-forget and returns
// AuthState.initializing() immediately. _init() then awaits several
// Firebase/DAO calls with (previously) zero try/catch anywhere in the
// method. AuthState.initializing's own doc comment says "Must not hang —
// see 19.6 startup hardening", but any exception during _init() — an
// offline reloadCurrentUser() call (AUD-account-03) or a DB read failure
// (AUD-account-11) — left `state` permanently stuck at `initializing`
// because the rejected Future was never observed by anything that resets
// `state`.
//
// Fix: _init() now wraps the Firebase-reload step in its own try/catch
// (falls through to the local-born restore path on failure) and wraps the
// whole method body in an outer try/catch (final safety net -> signedOut),
// logging via AppLogger on both paths.

@Tags(['unit', 'account', 'auth'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_repositories.dart';

/// DAO that throws on [findByTier] — simulates a DB read failure during
/// _init()'s local-born restore step (AUD-account-11's "and separately from
/// the DAO" acceptance criterion).
class _ThrowingUserProfileDao extends UserProfileDao {
  _ThrowingUserProfileDao(super.db);

  @override
  Future<List<UserProfile>> findByTier(UserTier tier) =>
      Future<List<UserProfile>>.error(
        Exception('simulated DB read failure (findByTier)'),
      );
}

class _ThrowingDaoUserDatabase extends UserDatabase {
  _ThrowingDaoUserDatabase(super.e);

  @override
  late final UserProfileDao userProfileDao = _ThrowingUserProfileDao(this);
}

const _uid = 'fb-uid-offline-cold-start';

AppUser _cloudUser() => const AppUser(
  uid: _uid,
  email: 'offline@example.test',
  displayName: 'Offline Cold Start',
  emailVerified: true,
  providers: ['password'],
);

/// Polls [authStateProvider] until it leaves `initializing` or [timeout]
/// elapses. Returns the settled state (still `initializing` on timeout —
/// callers assert it is NOT).
Future<AuthState> _settledStateOrTimeout(
  ProviderContainer container, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final state = container.read(authStateProvider);
    if (!state.isInitializing) return state;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return container.read(authStateProvider);
}

void main() {
  group('AUD-account-03: reloadCurrentUser() throws (offline cold start)', () {
    late UserDatabase userDb;
    late MockAuthRepository auth;

    setUp(() {
      userDb = UserDatabase(NativeDatabase.memory());
      auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(_cloudUser());
      // Simulates User.reload() throwing FirebaseAuthException(
      // network-request-failed) on an offline device — an ordinary
      // cold-start condition for an offline-first app.
      when(
        () => auth.reloadCurrentUser(),
      ).thenThrow(Exception('network-request-failed (simulated offline)'));
    });

    tearDown(() async => userDb.close());

    test(
      'AuthStateNotifier resolves to a terminal SessionStatus within a '
      'bounded time instead of remaining initializing indefinitely',
      () async {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userDatabaseProvider.overrideWithValue(userDb),
          ],
        );
        addTearDown(container.dispose);

        // Immediately after build(), state must still be initializing (the
        // splash window) — this is expected and correct.
        expect(container.read(authStateProvider).isInitializing, isTrue);

        final settled = await _settledStateOrTimeout(container);

        expect(
          settled.isInitializing,
          isFalse,
          reason:
              'AUD-account-03: a throwing reloadCurrentUser() must not leave '
              'sessionStatus stuck at initializing forever.',
        );
        // No local-born row was seeded, so the only correct terminal state
        // here is signedOut — never resurrect a session Firebase couldn't
        // confirm.
        expect(settled.isSignedIn, isFalse);

        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any((m) => m.contains('auth_state_init_cloud_reload_failed')),
          isTrue,
          reason:
              'Expected warning(event: "auth_state_init_cloud_reload_failed") '
              'in talker history.',
        );
      },
    );
  });

  group('AUD-account-11: DAO throws during the local-born restore step', () {
    late _ThrowingDaoUserDatabase userDb;
    late MockAuthRepository auth;

    setUp(() {
      userDb = _ThrowingDaoUserDatabase(NativeDatabase.memory());
      auth = MockAuthRepository();
      // No Firebase session at all — _init() should go straight to the
      // local-born restore path, which is where the DAO throws.
      when(() => auth.currentUser).thenReturn(null);
    });

    tearDown(() async => userDb.close());

    test('AuthStateNotifier settles to a terminal state (not stuck at '
        'initializing) when the local-born DAO query throws', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userDatabaseProvider.overrideWithValue(userDb),
        ],
      );
      addTearDown(container.dispose);

      final settled = await _settledStateOrTimeout(container);

      expect(
        settled.isInitializing,
        isFalse,
        reason:
            'AUD-account-11: _init() cannot leave sessionStatus at '
            'initializing on any exception path — it must resolve to '
            'signedIn or signedOut every time.',
      );
      expect(settled.isSignedIn, isFalse);

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('auth_state_init_failed')),
        isTrue,
        reason:
            'Expected error(event: "auth_state_init_failed") in talker '
            'history.',
      );
    });
  });
}
