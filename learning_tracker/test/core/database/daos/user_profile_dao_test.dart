import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('UserProfileDao', () {
    Future<int> insertTestProfile({
      String localUid = 'local-test-uid',
      String firebaseUid = 'uid-123',
      String displayName = 'Test User',
      String userMode = 'adult',
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final now = createdAt ?? DateTime.utc(2025, 1, 1);
      return database.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          localUid: localUid,
          firebaseUid: Value(firebaseUid),
          displayName: displayName,
          userMode: userMode,
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
      expect(profile.userMode, 'adult');
    });

    test('getUserProfileById returns null for non-existent id', () async {
      final profile = await database.userProfileDao.getUserProfileById(999);
      expect(profile, isNull);
    });

    test('getUserProfileByFirebaseUid finds by uid', () async {
      await insertTestProfile(localUid: 'local-abc', firebaseUid: 'abc');

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
      await insertTestProfile(localUid: 'local-1', firebaseUid: 'uid-1');
      await insertTestProfile(localUid: 'local-2', firebaseUid: 'uid-2');

      final profiles = await database.userProfileDao.getAllUserProfiles();
      expect(profiles, hasLength(2));
    });

    test('updateUserProfile modifies existing profile', () async {
      final id = await insertTestProfile();
      final profile = await database.userProfileDao.getUserProfileById(id);

      await database.userProfileDao.updateUserProfile(
        UserProfilesCompanion(
          id: Value(profile!.id),
          localUid: Value(profile.localUid),
          firebaseUid: Value(profile.firebaseUid),
          displayName: const Value('New Name'),
          userMode: Value(profile.userMode),
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

    test('upsertProfile inserts when no profile exists for uid', () async {
      await database.userProfileDao.upsertProfile(
        firebaseUid: 'new-uid',
        displayName: 'New User',
        userMode: 'child',
        updatedAt: DateTime.utc(2025, 1, 1),
      );

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'new-uid',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'New User');
      expect(profile.userMode, 'child');
    });

    test('upsertProfile updates when remote is newer', () async {
      await insertTestProfile(
        localUid: 'local-1',
        firebaseUid: 'uid-1',
        displayName: 'Old Name',
        updatedAt: DateTime.utc(2025, 1, 1),
      );

      await database.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'New Name',
        userMode: 'child',
        updatedAt: DateTime.utc(2025, 6, 1),
      );

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile!.displayName, 'New Name');
      expect(profile.userMode, 'child');
    });

    test('upsertProfile does not update when remote is older', () async {
      await insertTestProfile(
        localUid: 'local-1',
        firebaseUid: 'uid-1',
        displayName: 'Current Name',
        updatedAt: DateTime.utc(2025, 6, 1),
      );

      await database.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'Old Name',
        userMode: 'child',
        updatedAt: DateTime.utc(2025, 1, 1),
      );

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile!.displayName, 'Current Name');
    });
  });
}
