// Tests for AuthUser and AuthState — covers AuthUser.fromProfile (lines 31-37),
// displayIdentifier (lines 80-84), and AuthState.copyWith (lines 86-98).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  // =========================================================================
  // AuthUser.fromProfile
  // =========================================================================

  group('AuthUser.fromProfile', () {
    late UserDatabase db;

    setUp(() => db = inMemoryDb());
    tearDown(() => db.close());

    test('maps Account fields to AuthUser', () async {
      // Insert a profile account row.
      final now = DateTime.utc(2026, 1, 1);
      final profileId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              displayName: 'Test User',
              userMode: 'parent',
              tier: 'cloudBorn',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final profile =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals(profileId)))
              .getSingle();

      final user = AuthUser.fromProfile(profile);

      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.userMode, 'parent');
      expect(user.profileId, profileId);
      expect(user.firebaseUid, isNull);
    });
  });

  // =========================================================================
  // AuthState constructors
  // =========================================================================

  group('AuthState.initializing', () {
    test('has sessionStatus=initializing and null user/tier', () {
      const state = AuthState.initializing();
      expect(state.sessionStatus, SessionStatus.initializing);
      expect(state.currentUser, isNull);
      expect(state.tier, isNull);
      expect(state.isInitializing, isTrue);
      expect(state.isSignedIn, isFalse);
    });
  });

  group('AuthState.signedOut', () {
    test('has sessionStatus=signedOut and null user/tier', () {
      const state = AuthState.signedOut();
      expect(state.sessionStatus, SessionStatus.signedOut);
      expect(state.currentUser, isNull);
      expect(state.tier, isNull);
      expect(state.isSignedIn, isFalse);
    });
  });

  // =========================================================================
  // AuthState.displayIdentifier
  // =========================================================================

  group('AuthState.displayIdentifier', () {
    const authUser = AuthUser(
      profileId: 1,
      email: 'a@b.com',
      displayName: 'Alice',
      userMode: 'parent',
    );

    test('returns displayName when non-empty', () {
      const state = AuthState.signedIn(user: authUser, tier: UserTier.cloudBorn);
      expect(state.displayIdentifier, 'Alice');
    });

    test('returns email when displayName is empty', () {
      const emptyNameUser = AuthUser(
        profileId: 1,
        email: 'a@b.com',
        displayName: '',
        userMode: 'parent',
      );
      const state = AuthState.signedIn(
        user: emptyNameUser,
        tier: UserTier.cloudBorn,
      );
      expect(state.displayIdentifier, 'a@b.com');
    });

    test("returns 'anon' when signed out", () {
      const state = AuthState.signedOut();
      expect(state.displayIdentifier, 'anon');
    });
  });

  // =========================================================================
  // AuthState.copyWith
  // =========================================================================

  group('AuthState.copyWith', () {
    const authUser = AuthUser(
      profileId: 1,
      email: 'a@b.com',
      displayName: 'Alice',
      userMode: 'parent',
    );

    test('returns copy with updated sessionStatus', () {
      const state = AuthState.signedIn(user: authUser, tier: UserTier.cloudBorn);
      final copy = state.copyWith(sessionStatus: SessionStatus.signedOut);
      expect(copy.sessionStatus, SessionStatus.signedOut);
      expect(copy.currentUser, authUser);
    });

    test('clears user when clearUser=true', () {
      const state = AuthState.signedIn(user: authUser, tier: UserTier.cloudBorn);
      final copy = state.copyWith(clearUser: true);
      expect(copy.currentUser, isNull);
    });

    test('clears tier when clearTier=true', () {
      const state = AuthState.signedIn(user: authUser, tier: UserTier.cloudBorn);
      final copy = state.copyWith(clearTier: true);
      expect(copy.tier, isNull);
    });

    test('is cloudBorn / localBorn correctly', () {
      const cloud = AuthState.signedIn(user: authUser, tier: UserTier.cloudBorn);
      expect(cloud.isCloudBorn, isTrue);
      expect(cloud.isLocalBorn, isFalse);

      const local = AuthState.signedIn(user: authUser, tier: UserTier.localBorn);
      expect(local.isLocalBorn, isTrue);
      expect(local.isCloudBorn, isFalse);
    });
  });
}
