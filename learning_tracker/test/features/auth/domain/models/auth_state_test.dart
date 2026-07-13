// Tests for AuthUser and AuthState — covers AuthUser.fromProfile,
// displayIdentifier, and AuthState.copyWith.
//
// WS9.flows: userMode removed from AuthUser; mode lives on LearnerProfiles.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  // Build a minimal UserProfile so AuthUser.fromProfile can be tested
  // without a real database.
  UserProfile fakeProfile({
    int id = 1,
    String email = 'test@example.com',
    String displayName = 'Tester',
    String? firebaseUid,
  }) => UserProfile(
    id: id,
    email: email,
    displayName: displayName,
    tier: 'localBorn',
    firebaseUid: firebaseUid,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  // ── AuthUser.fromProfile ──────────────────────────────────────────────────

  group('AuthUser', () {
    test('fromProfile maps all fields correctly', () {
      final profile = fakeProfile(
        id: 42,
        email: 'user@example.com',
        displayName: 'Jane',
        firebaseUid: 'uid-abc',
      );
      final user = AuthUser.fromProfile(profile);

      expect(user.profileId, 42);
      expect(user.email, 'user@example.com');
      expect(user.displayName, 'Jane');
      expect(user.firebaseUid, 'uid-abc');
    });

    test('fromProfile handles null firebaseUid', () {
      final profile = fakeProfile(firebaseUid: null);
      final user = AuthUser.fromProfile(profile);
      expect(user.firebaseUid, isNull);
    });
  });

  group('AuthUser.fromProfile (DB-based)', () {
    late UserDatabase db;

    setUp(() => db = inMemoryDb());
    tearDown(() => db.close());

    test('maps Account fields to AuthUser', () async {
      final now = DateTime.utc(2026, 1, 1);
      final profileId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              displayName: 'Test User',
              tier: 'cloudBorn',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final profile = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(profileId))).getSingle();

      final user = AuthUser.fromProfile(profile);

      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.profileId, profileId);
    });
  });

  // ── AuthState constructors ────────────────────────────────────────────────

  group('AuthState', () {
    const testUser = AuthUser(
      profileId: 1,
      email: 'user@example.com',
      displayName: 'Test',
    );

    test('AuthState.initializing sets sessionStatus=initializing', () {
      const state = AuthState.initializing();
      expect(state.sessionStatus, SessionStatus.initializing);
      expect(state.currentUser, isNull);
      expect(state.tier, isNull);
    });

    test('AuthState.signedOut sets sessionStatus=signedOut', () {
      const state = AuthState.signedOut();
      expect(state.sessionStatus, SessionStatus.signedOut);
      expect(state.currentUser, isNull);
      expect(state.tier, isNull);
    });

    test('AuthState.signedIn sets sessionStatus=signedIn', () {
      const state = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );
      expect(state.sessionStatus, SessionStatus.signedIn);
      expect(state.currentUser, testUser);
      expect(state.tier, UserTier.localBorn);
    });

    test('isSignedIn is true only when signedIn', () {
      const signedIn = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );
      expect(signedIn.isSignedIn, isTrue);
      expect(const AuthState.signedOut().isSignedIn, isFalse);
      expect(const AuthState.initializing().isSignedIn, isFalse);
    });

    test('isInitializing is true only when initializing', () {
      expect(const AuthState.initializing().isInitializing, isTrue);
      expect(const AuthState.signedOut().isInitializing, isFalse);
    });

    test('isCloudBorn and isLocalBorn reflect tier', () {
      const cloudState = AuthState.signedIn(
        user: testUser,
        tier: UserTier.cloudBorn,
      );
      const localState = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );

      expect(cloudState.isCloudBorn, isTrue);
      expect(cloudState.isLocalBorn, isFalse);
      expect(localState.isLocalBorn, isTrue);
      expect(localState.isCloudBorn, isFalse);
    });

    test('displayIdentifier returns display name when present', () {
      const state = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );
      expect(state.displayIdentifier, 'Test');
    });

    test('displayIdentifier falls back to email when displayName is empty', () {
      const user = AuthUser(
        profileId: 1,
        email: 'user@example.com',
        displayName: '',
      );
      const state = AuthState.signedIn(user: user, tier: UserTier.localBorn);
      expect(state.displayIdentifier, 'user@example.com');
    });

    test('displayIdentifier returns anon when signed out', () {
      expect(const AuthState.signedOut().displayIdentifier, 'anon');
    });

    test('copyWith changes sessionStatus', () {
      const initial = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );
      final updated = initial.copyWith(sessionStatus: SessionStatus.signedOut);
      expect(updated.sessionStatus, SessionStatus.signedOut);
      // Other fields preserved
      expect(updated.tier, UserTier.localBorn);
      expect(updated.currentUser, testUser);
    });

    test('copyWith with clearUser=true nulls out currentUser', () {
      const state = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );
      final cleared = state.copyWith(clearUser: true);
      expect(cleared.currentUser, isNull);
    });

    test('copyWith with clearTier=true nulls out tier', () {
      const state = AuthState.signedIn(
        user: testUser,
        tier: UserTier.localBorn,
      );
      final cleared = state.copyWith(clearTier: true);
      expect(cleared.tier, isNull);
    });
  });

  // ── AUD-account-22: value equality ────────────────────────────────────────
  //
  // AppUser/AuthState/AuthUser previously had no ==/hashCode override, so two
  // instances with identical field values compared unequal by reference
  // identity — a landmine for any ref.watch(authStateProvider) call site that
  // forgot a .select(). AuthUser/AppUser are now @freezed (generated value
  // equality); AuthState gets hand-rolled value equality (see the class doc
  // comment for why @freezed isn't a safe fit for AuthState specifically).
  group('AUD-account-22: value equality', () {
    // userA()/userB() are built via two independent construction paths (a
    // direct const constructor call vs. the `.fromProfile` factory, which
    // always allocates fresh — freezed factories with a body are never
    // const-canonicalized) so `identical(a, b)` below is genuinely false:
    // this exercises real runtime value equality, not Dart's compile-time
    // `const` canonicalization.
    AuthUser userA() => const AuthUser(
      profileId: 7,
      email: 'a@b.com',
      displayName: 'A',
      firebaseUid: 'uid-7',
    );
    AuthUser userB() => AuthUser.fromProfile(
      UserProfile(
        id: 7,
        email: 'a@b.com',
        displayName: 'A',
        tier: 'cloudBorn',
        firebaseUid: 'uid-7',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    test('AuthUser(...) == AuthUser(...) is true for equal field values', () {
      final a = userA();
      final b = userB();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('AuthUser(...) != AuthUser(...) when a field differs (sanity check '
        'equality is not vacuously true)', () {
      const different = AuthUser(
        profileId: 8,
        email: 'a@b.com',
        displayName: 'A',
        firebaseUid: 'uid-7',
      );
      expect(userA(), isNot(equals(different)));
    });

    test('AuthState.signedIn(...) == AuthState.signedIn(...) is true for equal '
        'field values, even though currentUser/tier are constructed '
        'separately', () {
      final stateA = AuthState.signedIn(
        user: userA(),
        tier: UserTier.cloudBorn,
      );
      final stateB = AuthState.signedIn(
        user: userB(),
        tier: UserTier.cloudBorn,
      );
      expect(identical(stateA, stateB), isFalse);
      expect(stateA, equals(stateB));
      expect(stateA.hashCode, equals(stateB.hashCode));
    });

    test('AuthState.initializing() == AuthState.initializing() (both null '
        'user/tier)', () {
      expect(
        const AuthState.initializing(),
        equals(const AuthState.initializing()),
      );
    });

    test('AuthState instances with different sessionStatus are not equal even '
        'when currentUser/tier are both null', () {
      expect(
        const AuthState.initializing(),
        isNot(equals(const AuthState.signedOut())),
      );
    });
  });
}
