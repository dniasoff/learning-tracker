/// Unit tests for ChildModeGuard — parent mode only accessible from child accounts.
@Tags(['story_10_1'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late UserDatabase db;
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;

  setUp(() {
    db = createTestDatabase();
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();
  });

  tearDown(() async {
    await db.close();
  });

  test('no profiles defaults to adult — resolver.next(false)', () async {
    final guard = ChildModeGuard(database: db);

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(false)).called(1);
    verifyNever(() => mockResolver.next(true));
  });

  test('adult account blocked — resolver.next(false)', () async {
    await db.userProfileDao.insertUserProfile(
      UserProfilesCompanion.insert(
        firebaseUid: 'uid-1',
        displayName: 'Adult User',
        userMode: 'adult',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final guard = ChildModeGuard(database: db);

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(false)).called(1);
    verifyNever(() => mockResolver.next(true));
  });

  test('child account allowed — resolver.next(true)', () async {
    await db.userProfileDao.insertUserProfile(
      UserProfilesCompanion.insert(
        firebaseUid: 'uid-2',
        displayName: 'Child User',
        userMode: 'child',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final guard = ChildModeGuard(database: db);

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(true)).called(1);
    verifyNever(() => mockResolver.next(false));
  });
}
