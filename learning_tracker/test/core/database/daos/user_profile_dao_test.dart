import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = inMemoryDb();
  });

  tearDown(() async {
    await database.close();
  });

  group('UserProfileDao', () {
    Future<int> insertTestProfile({
      String email = 'test@test.local',
      String firebaseUid = 'uid-123',
      String tier = 'cloudBorn',
      String displayName = 'Test User',
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final now = createdAt ?? DateTime.utc(2025, 1, 1);
      return database.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          email: email,
          firebaseUid: Value(firebaseUid),
          tier: tier,
          displayName: displayName,
          createdAt: now,
          updatedAt: updatedAt ?? now,
        ),
      );
    }

    test('insertUserProfile and getUserProfileById', () async {
      final id = await insertTestProfile();

      final profile = await database.userProfileDao.getUserProfileById(id);
      expect(profile, isNotNull);
      expect(profile!.firebaseUid, 'uid-123');
      expect(profile.displayName, 'Test User');
      expect(profile.tier, 'cloudBorn');
    });

    test('getUserProfileById returns null for non-existent id', () async {
      final profile = await database.userProfileDao.getUserProfileById(999);
      expect(profile, isNull);
    });

    test('getUserProfileByFirebaseUid finds by uid', () async {
      await insertTestProfile(email: 'abc@test.local', firebaseUid: 'abc');

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'abc',
      );
      expect(profile, isNotNull);
      expect(profile!.firebaseUid, 'abc');
    });

    test('getUserProfileByFirebaseUid returns null for unknown uid', () async {
      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'unknown',
      );
      expect(profile, isNull);
    });

    test('getAllUserProfiles returns all profiles', () async {
      await insertTestProfile(email: 'a@test.local', firebaseUid: 'uid-1');
      await insertTestProfile(email: 'b@test.local', firebaseUid: 'uid-2');

      final profiles = await database.userProfileDao.getAllUserProfiles();
      expect(profiles, hasLength(2));
    });

    test('updateUserProfile modifies existing profile', () async {
      final id = await insertTestProfile();
      final profile = await database.userProfileDao.getUserProfileById(id);

      await database.userProfileDao.updateUserProfile(
        UserProfilesCompanion(
          id: Value(profile!.id),
          email: Value(profile.email),
          firebaseUid: Value(profile.firebaseUid),
          tier: Value(profile.tier),
          displayName: const Value('New Name'),
          createdAt: Value(profile.createdAt),
          updatedAt: Value(DateTime.utc(2025, 6, 1)),
        ),
      );

      final updated = await database.userProfileDao.getUserProfileById(id);
      expect(updated!.displayName, 'New Name');
    });

    test('deleteUserProfile removes the profile', () async {
      final id = await insertTestProfile();

      final deleted = await database.userProfileDao.deleteUserProfile(id);
      expect(deleted, 1);

      final profile = await database.userProfileDao.getUserProfileById(id);
      expect(profile, isNull);
    });

    test('findByTier returns only matching tier', () async {
      await insertTestProfile(
        email: 'cloud@test.local',
        firebaseUid: 'cloud-1',
        tier: 'cloudBorn',
      );
      await database.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          email: 'local@test.local',
          tier: 'localBorn',
          passwordHash: const Value(r'argon2id$hash'),
          displayName: 'Local',
          createdAt: DateTime.utc(2025, 1, 1),
          updatedAt: DateTime.utc(2025, 1, 1),
        ),
      );

      final locals = await database.userProfileDao.findByTier(
        UserTier.localBorn,
      );
      expect(locals, hasLength(1));
      expect(locals.first.email, 'local@test.local');
    });

    test('findLocalBornByEmail ignores cloud-born rows', () async {
      await insertTestProfile(
        email: 'shared@test.local',
        firebaseUid: 'cloud-shared',
        tier: 'cloudBorn',
      );

      final missing = await database.userProfileDao.findLocalBornByEmail(
        'shared@test.local',
      );
      expect(missing, isNull);
    });

    test('upgradeLocalToCloud flips tier atomically', () async {
      final id = await database.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          email: 'upgrade@test.local',
          tier: 'localBorn',
          passwordHash: const Value(r'argon2id$hash'),
          displayName: 'Upgrade Me',
          createdAt: DateTime.utc(2025, 1, 1),
          updatedAt: DateTime.utc(2025, 1, 1),
        ),
      );

      await database.userProfileDao.upgradeLocalToCloud(
        profileId: id,
        firebaseUid: 'new-firebase-uid',
        updatedAt: DateTime.utc(2025, 2, 1),
      );

      final upgraded = await database.userProfileDao.getUserProfileById(id);
      expect(upgraded!.tier, 'cloudBorn');
      expect(upgraded.firebaseUid, 'new-firebase-uid');
      expect(upgraded.passwordHash, isNull);
    });

    test('upsertProfile inserts when no profile exists for uid', () async {
      await database.userProfileDao.upsertProfile(
        firebaseUid: 'new-uid',
        displayName: 'New User',
        updatedAt: DateTime.utc(2025, 1, 1),
      );

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'new-uid',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'New User');
      expect(profile.tier, 'cloudBorn');
    });

    test('upsertProfile updates when remote is newer', () async {
      await insertTestProfile(
        email: 'uid1@test.local',
        firebaseUid: 'uid-1',
        displayName: 'Old Name',
        updatedAt: DateTime.utc(2025, 1, 1),
      );

      await database.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'New Name',
        updatedAt: DateTime.utc(2025, 6, 1),
      );

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile!.displayName, 'New Name');
    });

    test('upsertProfile does not update when remote is older', () async {
      await insertTestProfile(
        email: 'uid1@test.local',
        firebaseUid: 'uid-1',
        displayName: 'Current Name',
        updatedAt: DateTime.utc(2025, 6, 1),
      );

      await database.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'Old Name',
        updatedAt: DateTime.utc(2025, 1, 1),
      );

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile!.displayName, 'Current Name');
    });
  });
}
