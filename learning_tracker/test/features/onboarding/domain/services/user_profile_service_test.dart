import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late UserProfileService service;
  late List<Map<String, String>> firestorePushes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    firestorePushes = [];
    service = UserProfileService(
      userProfileDao: db.userProfileDao,
      pushUserProfile:
          ({
            required String firebaseUid,
            required String displayName,
            required String userMode,
          }) async {
            firestorePushes.add({
              'firebaseUid': firebaseUid,
              'displayName': displayName,
              'userMode': userMode,
            });
          },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('UserProfileService', () {
    test('setUserMode persists child mode to local database', () async {
      await service.setUserMode(
        firebaseUid: 'uid-123',
        displayName: 'Test User',
        mode: UserMode.child,
      );

      final mode = await service.getUserMode('uid-123');
      expect(mode, UserMode.child);
    });

    test('setUserMode persists adult mode to local database', () async {
      await service.setUserMode(
        firebaseUid: 'uid-456',
        displayName: 'Adult User',
        mode: UserMode.adult,
      );

      final mode = await service.getUserMode('uid-456');
      expect(mode, UserMode.adult);
    });

    test('setUserMode writes to Firestore', () async {
      await service.setUserMode(
        firebaseUid: 'uid-789',
        displayName: 'Test',
        mode: UserMode.child,
      );

      expect(firestorePushes, hasLength(1));
      expect(firestorePushes.first['firebaseUid'], 'uid-789');
      expect(firestorePushes.first['displayName'], 'Test');
      expect(firestorePushes.first['userMode'], 'child');
    });

    test('getUserMode returns null for unknown user', () async {
      final mode = await service.getUserMode('nonexistent');
      expect(mode, isNull);
    });

    test('setUserMode can update existing mode', () async {
      await service.setUserMode(
        firebaseUid: 'uid-update',
        displayName: 'User',
        mode: UserMode.child,
      );

      await service.setUserMode(
        firebaseUid: 'uid-update',
        displayName: 'User',
        mode: UserMode.adult,
      );

      final mode = await service.getUserMode('uid-update');
      expect(mode, UserMode.adult);
    });
  });
}
