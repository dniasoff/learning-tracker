// Tests for UserProfileService.updateDisplayName.
//
// WS9.flows: setUserMode / getUserMode removed from UserProfileService.
// Mode belongs to LearnerProfiles, not to an Account.
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:test/test.dart';

void main() {
  late UserDatabase db;
  late UserProfileService service;
  late List<Map<String, String>> firestorePushes;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    firestorePushes = [];
    service = UserProfileService(
      userProfileDao: db.userProfileDao,
      pushUserProfile:
          ({required String firebaseUid, required String displayName}) async {
            firestorePushes.add({
              'firebaseUid': firebaseUid,
              'displayName': displayName,
            });
          },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('UserProfileService', () {
    test('updateDisplayName persists to local database', () async {
      await service.updateDisplayName(
        firebaseUid: 'uid-123',
        displayName: 'Alice',
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-123',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Alice');
    });

    test('updateDisplayName writes to Firestore', () async {
      await service.updateDisplayName(
        firebaseUid: 'uid-789',
        displayName: 'Bob',
      );

      expect(firestorePushes, hasLength(1));
      expect(firestorePushes.first['firebaseUid'], 'uid-789');
      expect(firestorePushes.first['displayName'], 'Bob');
      // userMode is no longer pushed — mode belongs to LearnerProfiles
      expect(firestorePushes.first.containsKey('userMode'), isFalse);
    });

    test('updateDisplayName updates existing entry', () async {
      await service.updateDisplayName(
        firebaseUid: 'uid-update',
        displayName: 'First Name',
      );

      await service.updateDisplayName(
        firebaseUid: 'uid-update',
        displayName: 'Updated Name',
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-update',
      );
      expect(profile!.displayName, 'Updated Name');
    });
  });
}
