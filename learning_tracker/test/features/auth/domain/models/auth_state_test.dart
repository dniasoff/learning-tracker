// Tests for AuthUser and AuthState — covers AuthUser.fromAccount,
// displayIdentifier, and AuthState.copyWith.
//
// WS9.flows: userMode removed from AuthUser; mode lives on LearnerProfiles.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';

void main() {
  // Build a minimal AccountEntity so AuthUser.fromAccount can be tested
  // without a database or Firebase SDK.
  AccountEntity fakeAccount({
    String uid = 'uid-1',
    String? email = 'test@example.com',
    String displayName = 'Tester',
  }) => AccountEntity(
    uid: uid,
    email: email,
    displayName: displayName,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  // ── AuthUser.fromAccount ──────────────────────────────────────────────────

  group('AuthUser', () {
    test('fromAccount maps all fields correctly', () {
      final account = fakeAccount(
        uid: 'uid-42',
        email: 'user@example.com',
        displayName: 'Jane',
      );
      final user = AuthUser.fromAccount(account);

      expect(user.uid, 'uid-42');
      expect(user.email, 'user@example.com');
      expect(user.displayName, 'Jane');
      expect(user.firebaseUid, 'uid-42');
    });

    test('fromAccount handles a null email', () {
      final user = AuthUser.fromAccount(fakeAccount(email: null));
      expect(user.email, isEmpty);
    });
  });

  // ── AuthState constructors ────────────────────────────────────────────────

  group('AuthState', () {
    const testUser = AuthUser(
      uid: 'uid-1',
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
      const state = AuthState.signedIn(user: testUser, tier: Tier.local);
      expect(state.sessionStatus, SessionStatus.signedIn);
      expect(state.currentUser, testUser);
      expect(state.tier, Tier.local);
    });

    test('isSignedIn is true only when signedIn', () {
      const signedIn = AuthState.signedIn(user: testUser, tier: Tier.local);
      expect(signedIn.isSignedIn, isTrue);
      expect(const AuthState.signedOut().isSignedIn, isFalse);
      expect(const AuthState.initializing().isSignedIn, isFalse);
    });

    test('isInitializing is true only when initializing', () {
      expect(const AuthState.initializing().isInitializing, isTrue);
      expect(const AuthState.signedOut().isInitializing, isFalse);
    });

    test('isCloudBorn and isLocalBorn reflect tier', () {
      const cloudState = AuthState.signedIn(user: testUser, tier: Tier.cloud);
      const localState = AuthState.signedIn(user: testUser, tier: Tier.local);

      expect(cloudState.isCloudBorn, isTrue);
      expect(cloudState.isLocalBorn, isFalse);
      expect(localState.isLocalBorn, isTrue);
      expect(localState.isCloudBorn, isFalse);
    });

    test('displayIdentifier returns display name when present', () {
      const state = AuthState.signedIn(user: testUser, tier: Tier.local);
      expect(state.displayIdentifier, 'Test');
    });

    test('displayIdentifier falls back to email when displayName is empty', () {
      const user = AuthUser(
        uid: 'uid-1',
        email: 'user@example.com',
        displayName: '',
      );
      const state = AuthState.signedIn(user: user, tier: Tier.local);
      expect(state.displayIdentifier, 'user@example.com');
    });

    test('displayIdentifier returns anon when signed out', () {
      expect(const AuthState.signedOut().displayIdentifier, 'anon');
    });

    test('copyWith changes sessionStatus', () {
      const initial = AuthState.signedIn(user: testUser, tier: Tier.local);
      final updated = initial.copyWith(sessionStatus: SessionStatus.signedOut);
      expect(updated.sessionStatus, SessionStatus.signedOut);
      // Other fields preserved
      expect(updated.tier, Tier.local);
      expect(updated.currentUser, testUser);
    });

    test('copyWith with clearUser=true nulls out currentUser', () {
      const state = AuthState.signedIn(user: testUser, tier: Tier.local);
      final cleared = state.copyWith(clearUser: true);
      expect(cleared.currentUser, isNull);
    });

    test('copyWith with clearTier=true nulls out tier', () {
      const state = AuthState.signedIn(user: testUser, tier: Tier.local);
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
    // direct const constructor call vs. the `.fromAccount` factory, which
    // always allocates fresh — freezed factories with a body are never
    // const-canonicalized) so `identical(a, b)` below is genuinely false:
    // this exercises real runtime value equality, not Dart's compile-time
    // `const` canonicalization.
    AuthUser userA() => const AuthUser(
      uid: 'uid-7',
      email: 'a@b.com',
      displayName: 'A',
      firebaseUid: 'uid-7',
    );
    AuthUser userB() => AuthUser.fromAccount(
      AccountEntity(
        uid: 'uid-7',
        email: 'a@b.com',
        displayName: 'A',
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
        uid: 'uid-8',
        email: 'a@b.com',
        displayName: 'A',
        firebaseUid: 'uid-7',
      );
      expect(userA(), isNot(equals(different)));
    });

    test('AuthState.signedIn(...) == AuthState.signedIn(...) is true for equal '
        'field values, even though currentUser/tier are constructed '
        'separately', () {
      final stateA = AuthState.signedIn(user: userA(), tier: Tier.cloud);
      final stateB = AuthState.signedIn(user: userB(), tier: Tier.cloud);
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
