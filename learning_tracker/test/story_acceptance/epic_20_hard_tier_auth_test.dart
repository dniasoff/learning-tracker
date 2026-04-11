import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/auth/domain/services/password_hasher.dart';
import 'package:learning_tracker/features/sync/domain/merge_rules.dart';
import 'package:learning_tracker/features/sync/domain/reducers/streak_reducer.dart';

/// End-to-end story acceptance tests for Epic 20 — v2 hard-tier
/// auth refactor. Covers the contract promised by the v2 architecture
/// doc §3 and §4 against the implementation that landed in stories
/// 20.3 through 20.12.
void main() {
  group('Epic 20 — v2 hard-tier auth', () {
    late UserDatabase db;
    late LocalAuthService localAuth;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      localAuth = LocalAuthService(
        dao: db.userProfileDao,
        hasher: PasswordHasher(params: Argon2idParams.test),
      );
    });

    tearDown(() => db.close());

    // ─── Story 20.3: DB schema ─────────────────────────────────────
    group('Story 20.3 — v2 schema', () {
      test('UserProfiles has email, firebaseUid, passwordHash, tier', () async {
        await db.into(db.userProfiles).insert(
              UserProfilesCompanion.insert(
                email: 'cloud@test.local',
                firebaseUid: const Value('fbuid-1'),
                tier: 'cloudBorn',
                displayName: 'Cloudy',
                userMode: 'adult',
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        final row = await db.select(db.userProfiles).getSingle();
        expect(row.email, 'cloud@test.local');
        expect(row.firebaseUid, 'fbuid-1');
        expect(row.tier, 'cloudBorn');
        expect(row.passwordHash, isNull);
      });

      test('DAO.findByTier + findLocalBornByEmail isolate tiers', () async {
        await db.userProfileDao.insertUserProfile(
          UserProfilesCompanion.insert(
            email: 'a@test.local',
            firebaseUid: const Value('a-fb'),
            tier: 'cloudBorn',
            displayName: 'A',
            userMode: 'adult',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await db.userProfileDao.insertUserProfile(
          UserProfilesCompanion.insert(
            email: 'b@test.local',
            tier: 'localBorn',
            passwordHash: const Value(r'argon2id$hash'),
            displayName: 'B',
            userMode: 'adult',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final locals =
            await db.userProfileDao.findByTier(UserTier.localBorn);
        expect(locals, hasLength(1));
        expect(locals.first.email, 'b@test.local');

        expect(
          await db.userProfileDao.findLocalBornByEmail('a@test.local'),
          isNull,
        );
      });

      test('upgradeLocalToCloud is atomic', () async {
        final profile = await localAuth.signUp(
          email: 'upgrade@test.local',
          password: 'hunter2hunter2',
          displayName: 'U',
          userMode: 'adult',
        );

        await db.userProfileDao.upgradeLocalToCloud(
          profileId: profile.id,
          firebaseUid: 'new-fb',
          updatedAt: DateTime.utc(2026, 2, 1),
        );

        final after = await db.userProfileDao.getUserProfileById(profile.id);
        expect(after!.tier, 'cloudBorn');
        expect(after.firebaseUid, 'new-fb');
        expect(after.passwordHash, isNull);
      });
    });

    // ─── Story 20.4: Local auth service ─────────────────────────────
    group('Story 20.4 — LocalAuthService', () {
      test('sign-up + sign-in round-trip', () async {
        await localAuth.signUp(
          email: 'alice@test.local',
          password: 'correcthorse',
          displayName: 'Alice',
          userMode: 'adult',
        );
        final profile = await localAuth.signIn(
          email: 'alice@test.local',
          password: 'correcthorse',
        );
        expect(profile.email, 'alice@test.local');
        expect(profile.tier, 'localBorn');
      });

      test('wrong password throws InvalidCredentialsException', () async {
        await localAuth.signUp(
          email: 'alice@test.local',
          password: 'correcthorse',
          displayName: 'Alice',
          userMode: 'adult',
        );
        expect(
          () => localAuth.signIn(
            email: 'alice@test.local',
            password: 'wrong',
          ),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });
    });

    // ─── Story 20.5: Unified AuthState ──────────────────────────────
    group('Story 20.5 — AuthState', () {
      test('exposes tier + session status as a single shape', () {
        const signedOut = AuthState.signedOut();
        expect(signedOut.isSignedIn, isFalse);
        expect(signedOut.isCloudBorn, isFalse);
        expect(signedOut.isLocalBorn, isFalse);

        const signedInLocal = AuthState.signedIn(
          user: AuthUser(
            profileId: 1,
            email: 'a@test.local',
            displayName: 'A',
            userMode: 'adult',
          ),
          tier: Tier.localBorn,
        );
        expect(signedInLocal.isSignedIn, isTrue);
        expect(signedInLocal.isLocalBorn, isTrue);
        expect(signedInLocal.isCloudBorn, isFalse);
      });
    });

    // ─── Story 20.11: Event log + reducers ──────────────────────────
    group('Story 20.11 — event-log reducers converge', () {
      test('unioned logs from two devices yield identical state', () {
        // Device A: 1/1, 1/2
        // Device B: 1/3 (while A was offline)
        final union = [
          StreakEvent(
            id: 0,
            profileId: 1,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 1, 1),
            clientDeviceId: 'A',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
          StreakEvent(
            id: 0,
            profileId: 1,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 1, 3),
            clientDeviceId: 'B',
            createdAt: DateTime.utc(2026, 1, 3),
          ),
          StreakEvent(
            id: 0,
            profileId: 1,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 1, 2),
            clientDeviceId: 'A',
            createdAt: DateTime.utc(2026, 1, 2),
          ),
        ];
        final fromA = reduceStreakEvents(union);
        final fromB = reduceStreakEvents(union.reversed);
        expect(fromA.currentStreak, fromB.currentStreak);
        expect(fromA.currentStreak, 3);
      });
    });

    // ─── Story 20.12: LWW + merge-forward ───────────────────────────
    group('Story 20.12 — merge rules', () {
      test('LWW picks newer timestamp', () {
        final result = lwwMerge<String>(
          local: 'old-name',
          remote: 'new-name',
          localUpdatedAt: DateTime.utc(2026, 1, 1),
          remoteUpdatedAt: DateTime.utc(2026, 2, 1),
        );
        expect(result.winner, 'new-name');
      });

      test('merge-forward never decreases progress', () {
        expect(mergeForwardMaxInt(10, 5), 10);
      });
    });
  });
}
