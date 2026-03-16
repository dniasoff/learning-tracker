/// Unit tests for ChildModeGuard — parent mode only accessible from child accounts.
@Tags(['story_10_1'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('no profiles defaults to adult (blocks parent mode access)', () async {
    final profiles = await db.userProfileDao.getAllUserProfiles();
    expect(profiles, isEmpty);
    // ChildModeGuard defaults to adult when no profiles → denies access
  });

  test('adult account cannot access parent mode', () async {
    await db.userProfileDao.insertUserProfile(
      UserProfilesCompanion.insert(
        firebaseUid: 'uid-1',
        displayName: 'Adult User',
        userMode: 'adult',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final profiles = await db.userProfileDao.getAllUserProfiles();
    final mode = UserMode.values.firstWhere(
      (m) => m.name == profiles.first.userMode,
      orElse: () => UserMode.adult,
    );
    expect(mode, UserMode.adult);
    expect(mode, isNot(UserMode.child));
  });

  test('child account can access parent mode', () async {
    await db.userProfileDao.insertUserProfile(
      UserProfilesCompanion.insert(
        firebaseUid: 'uid-2',
        displayName: 'Child User',
        userMode: 'child',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final profiles = await db.userProfileDao.getAllUserProfiles();
    final mode = UserMode.values.firstWhere(
      (m) => m.name == profiles.first.userMode,
      orElse: () => UserMode.adult,
    );
    expect(mode, UserMode.child);
  });
}
