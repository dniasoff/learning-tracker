import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

Future<int> _insertProfile(
  UserDatabase db, {
  required String mode,
  int accountId = 1,
}) async {
  final now = DateTime.now().toUtc();
  return db
      .into(db.learnerProfiles)
      .insert(
        ProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'test-$mode',
          mode: mode,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

ProviderContainer _makeContainer(UserDatabase db) {
  return ProviderContainer(
    overrides: [userDatabaseProvider.overrideWithValue(db)],
  );
}

void main() {
  group('dashboardUserModeProvider', () {
    late UserDatabase db;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      // Seed account row for FK on learner_profiles.account_id.
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              tier: 'localBorn',
              displayName: 'Test Account',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns child when active profile mode is child', () async {
      final profileId = await _insertProfile(db, mode: 'child');
      final container = _makeContainer(db);
      addTearDown(container.dispose);
      container.read(selectedProfileIdProvider.notifier).select(profileId);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);
    });

    test('returns adult when active profile mode is adult', () async {
      final profileId = await _insertProfile(db, mode: 'adult');
      final container = _makeContainer(db);
      addTearDown(container.dispose);
      container.read(selectedProfileIdProvider.notifier).select(profileId);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });

    test('defaults to adult when no profile row exists', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);
      container.read(selectedProfileIdProvider.notifier).select(9999);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });
  });
}
