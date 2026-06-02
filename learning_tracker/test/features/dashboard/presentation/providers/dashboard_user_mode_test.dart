import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
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

/// Fake [ActiveProfileId] that pins the active profile to a fixed id, used to
/// simulate a tutored session where the active profile is the talmid's
/// synthetic child mirror (not the tutor's own selected profile).
class _FixedActiveProfileId extends ActiveProfileId {
  _FixedActiveProfileId(this._id);
  final int _id;
  @override
  int build() => _id;
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

    test(
      'returns child for a tutored CHILD mirror even though the tutor is an '
      'adult (Bug 1 regression: tutor must see the talmid points/rewards)',
      () async {
        // The signed-in tutor's own selected profile is an adult.
        final tutorAdultId = await _insertProfile(db, mode: 'adult');
        // The talmid (tutored child) mirror that becomes the ACTIVE profile.
        final talmidChildId = await _insertProfile(db, mode: 'child');

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            // Tutored session: active profile is the talmid child mirror, not
            // the tutor's own selected adult profile.
            activeProfileIdProvider.overrideWith(
              () => _FixedActiveProfileId(talmidChildId),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(selectedProfileIdProvider.notifier).select(tutorAdultId);

        final mode = await container.read(dashboardUserModeProvider.future);
        // Must follow the ACTIVE (child) profile, not the tutor's adult mode.
        expect(mode, ProfileMode.child);
      },
    );

    test('defaults to adult when no profile row exists', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);
      container.read(selectedProfileIdProvider.notifier).select(9999);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });
  });
}
