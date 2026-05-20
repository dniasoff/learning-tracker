/// Unit tests for ChildModeGuard — parent mode only accessible from child profiles.
@Tags(['story_10_1'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

Future<int> _insertProfile(
  UserDatabase db, {
  required String mode,
  String displayName = 'Learner',
}) {
  return db
      .into(db.learnerProfiles)
      .insert(
        ProfilesCompanion.insert(
          accountId: 1,
          displayName: displayName,
          mode: mode,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}

void main() {
  late UserDatabase db;
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;

  setUp(() async {
    db = createTestDatabase();
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();
    // Seed account row for FK on learner_profiles.account_id.
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('no selected profile is denied — resolver.next(false)', () async {
    final guard = ChildModeGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => null,
    );

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(false)).called(1);
    verifyNever(() => mockResolver.next(true));
  });

  test('selected id points to missing profile is denied', () async {
    final guard = ChildModeGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => 999,
    );

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(false)).called(1);
    verifyNever(() => mockResolver.next(true));
  });

  test('adult profile blocked — resolver.next(false)', () async {
    final id = await _insertProfile(db, mode: 'adult');
    final guard = ChildModeGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => id,
    );

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(false)).called(1);
    verifyNever(() => mockResolver.next(true));
  });

  test('child profile allowed — resolver.next(true)', () async {
    final id = await _insertProfile(db, mode: 'child');
    final guard = ChildModeGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => id,
    );

    await guard.onNavigation(mockResolver, mockRouter);

    verify(() => mockResolver.next(true)).called(1);
    verifyNever(() => mockResolver.next(false));
  });
}
