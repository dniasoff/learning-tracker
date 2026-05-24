import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase database;

  setUp(() async {
    database = inMemoryDb();
    // Seed accounts id=1 and id=2 — learner_profiles.account_id FK requires them.
    // Some tests insert profiles for accountId=2 (e.g. getProfilesByAccount,
    // countProfilesForAccount), so both accounts must exist.
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'test@example.com',
            tier: 'localBorn',
            displayName: 'Test Account',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'test2@example.com',
            tier: 'localBorn',
            displayName: 'Test Account 2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  group('ProfileDao', () {
    ProfilesCompanion makeProfile({
      int accountId = 1,
      String displayName = 'Test User',
      String mode = 'adult',
      int avatarIndex = 0,
    }) {
      final now = DateTime.now();
      return ProfilesCompanion.insert(
        accountId: accountId,
        displayName: displayName,
        mode: mode,
        avatarIndex: Value(avatarIndex),
        createdAt: now,
        updatedAt: now,
      );
    }

    test(
      'insertProfile returns an id and getProfileById retrieves it',
      () async {
        final id = await database.profileDao.insertProfile(makeProfile());

        final profile = await database.profileDao.getProfileById(id);
        expect(profile, isNotNull);
        expect(profile!.displayName, 'Test User');
        expect(profile.mode, 'adult');
        expect(profile.accountId, 1);
      },
    );

    test('getProfileById returns null for non-existent id', () async {
      final profile = await database.profileDao.getProfileById(999);
      expect(profile, isNull);
    });

    test('getProfilesByAccount filters by accountId', () async {
      await database.profileDao.insertProfile(
        makeProfile(accountId: 1, displayName: 'A'),
      );
      await database.profileDao.insertProfile(
        makeProfile(accountId: 2, displayName: 'B'),
      );
      await database.profileDao.insertProfile(
        makeProfile(accountId: 1, displayName: 'C'),
      );

      final profiles = await database.profileDao.getProfilesByAccount(1);
      expect(profiles, hasLength(2));
    });

    test('countProfilesForAccount returns correct count', () async {
      await database.profileDao.insertProfile(makeProfile(accountId: 1));
      await database.profileDao.insertProfile(makeProfile(accountId: 1));
      await database.profileDao.insertProfile(makeProfile(accountId: 2));

      expect(await database.profileDao.countProfilesForAccount(1), 2);
      expect(await database.profileDao.countProfilesForAccount(2), 1);
      expect(await database.profileDao.countProfilesForAccount(3), 0);
    });

    test('updateProfile modifies existing profile', () async {
      final id = await database.profileDao.insertProfile(makeProfile());
      final profile = await database.profileDao.getProfileById(id);

      final updated = await database.profileDao.updateProfile(
        ProfilesCompanion(
          id: Value(profile!.id),
          accountId: Value(profile.accountId),
          displayName: const Value('Updated Name'),
          mode: Value(profile.mode),
          avatarIndex: Value(profile.avatarIndex),
          createdAt: Value(profile.createdAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
      expect(updated, isTrue);

      final fetched = await database.profileDao.getProfileById(id);
      expect(fetched!.displayName, 'Updated Name');
    });

    test('deleteProfile removes the profile', () async {
      final id = await database.profileDao.insertProfile(makeProfile());

      final deleted = await database.profileDao.deleteProfile(id);
      expect(deleted, 1);

      final profile = await database.profileDao.getProfileById(id);
      expect(profile, isNull);
    });

    test('watchProfilesByAccount emits updates', () async {
      final stream = database.profileDao.watchProfilesByAccount(1);

      expect(
        stream,
        emitsInOrder([
          <Profile>[], // initial empty
          hasLength(1), // after insert
        ]),
      );

      await Future<void>.delayed(Duration.zero);
      await database.profileDao.insertProfile(makeProfile(accountId: 1));
    });

    // ── profileExistsByName (DNI-174) ────────────────────────────────────────

    test('profileExistsByName returns true for exact match', () async {
      await database.profileDao.insertProfile(
        makeProfile(displayName: 'Daniel'),
      );
      expect(
        await database.profileDao.profileExistsByName(1, 'Daniel'),
        isTrue,
      );
    });

    test('profileExistsByName is case-insensitive', () async {
      await database.profileDao.insertProfile(
        makeProfile(displayName: 'Daniel'),
      );
      expect(
        await database.profileDao.profileExistsByName(1, 'daniel'),
        isTrue,
      );
      expect(
        await database.profileDao.profileExistsByName(1, 'DANIEL'),
        isTrue,
      );
    });

    test('profileExistsByName trims whitespace', () async {
      await database.profileDao.insertProfile(
        makeProfile(displayName: 'Daniel'),
      );
      expect(
        await database.profileDao.profileExistsByName(1, '  Daniel  '),
        isTrue,
      );
    });

    test('profileExistsByName returns false for different account', () async {
      await database.profileDao.insertProfile(
        makeProfile(accountId: 1, displayName: 'Daniel'),
      );
      expect(
        await database.profileDao.profileExistsByName(2, 'Daniel'),
        isFalse,
      );
    });

    test('profileExistsByName excludeId skips self', () async {
      final id = await database.profileDao.insertProfile(
        makeProfile(displayName: 'Daniel'),
      );
      expect(
        await database.profileDao.profileExistsByName(
          1,
          'Daniel',
          excludeId: id,
        ),
        isFalse,
      );
    });

    test('profileExistsByName returns false for no match', () async {
      await database.profileDao.insertProfile(
        makeProfile(displayName: 'Daniel'),
      );
      expect(
        await database.profileDao.profileExistsByName(1, 'Sarah'),
        isFalse,
      );
    });
  });
}
