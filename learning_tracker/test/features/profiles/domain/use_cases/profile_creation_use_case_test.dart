/// Unit tests for [ProfileCreationUseCase] — Story 26.12 (DNI-355).
///
/// Key acceptance criteria under test:
///   1. Happy path: profile row + curriculum tracks + stages + point configs
///      are all written in one go.
///   2. Rollback: a failure mid-transaction leaves zero new rows in every table.
///   3. Pre-flight guards: max-profiles and duplicate-name are enforced before
///      the transaction opens.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/use_cases/profile_creation_use_case.dart';

UserDatabase makeInMemoryDb() => UserDatabase(NativeDatabase.memory());

void main() {
  late UserDatabase db;
  late ProfileCreationUseCase useCase;

  setUp(() async {
    db = makeInMemoryDb();
    useCase = ProfileCreationUseCase(db);
    // Seed account row for FK on learner_profiles.account_id.
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'test@example.com',
            tier: 'localBorn',
            displayName: 'Test Account',
            userMode: 'adult',
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<int> countRows<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
  ) async {
    final count = countAll();
    final query = db.selectOnly(table)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Happy-path tests
  // ---------------------------------------------------------------------------

  group('execute — happy path', () {
    test('creates profile row with correct fields', () async {
      const command = ProfileCreationCommand(
        accountId: 1,
        displayName: '  Yosef  ',
        mode: 'adult',
        avatarIndex: 2,
      );

      final result = await useCase.execute(command);

      expect(result.profile.displayName, 'Yosef');
      expect(result.profile.accountId, 1);
      expect(result.profile.mode, 'adult');
      expect(result.profile.avatarIndex, 2);
      expect(result.profile.id, isPositive);

      final row = await db.profileDao.getProfileById(result.profile.id);
      expect(row, isNotNull);
      expect(row!.displayName, 'Yosef');
    });

    test(
      'profile-only command (empty curricula) writes exactly one profile row',
      () async {
        const command = ProfileCreationCommand(
          accountId: 1,
          displayName: 'Solo',
          mode: 'child',
        );

        await useCase.execute(command);

        expect(await countRows(db.learnerProfiles), 1);
        expect(await countRows(db.curriculumTracks), 0);
        expect(await countRows(db.stageDefinitions), 0);
        expect(await countRows(db.pointConfigs), 0);
      },
    );

    test(
      'seeds tracks, stages, and point configs for each requested curriculum',
      () async {
        const command = ProfileCreationCommand(
          accountId: 1,
          displayName: 'Dov',
          mode: 'adult',
          curriculumIds: [CurriculumId.mishnayos, CurriculumId.bavli],
        );

        await useCase.execute(command);

        // One track per curriculum.
        expect(await countRows(db.curriculumTracks), 2);

        // 3 default stages × 2 curricula = 6.
        expect(await countRows(db.stageDefinitions), 6);

        // 3 default point configs × 2 curricula = 6.
        expect(await countRows(db.pointConfigs), 6);
      },
    );

    test('multiple profiles for the same account are all written', () async {
      for (var i = 1; i <= 3; i++) {
        await useCase.execute(
          ProfileCreationCommand(
            accountId: 1,
            displayName: 'Profile $i',
            mode: 'adult',
          ), // Cannot be const because displayName uses string interpolation.
        );
      }

      final profiles = await db.profileDao.getProfilesByAccount(1);
      expect(profiles, hasLength(3));
    });
  });

  // ---------------------------------------------------------------------------
  // Rollback test — the core acceptance criterion for Story 26.12
  // ---------------------------------------------------------------------------

  group('execute — mid-transaction failure rolls back all writes', () {
    test(
      'zero rows in every table when the transaction throws mid-flight',
      () async {
        // We trigger a failure by inserting a duplicate stage row inside the
        // same transaction. The second curriculum activation will try to insert
        // a track row that violates the unique key
        // (profileId, curriculumId, trackType) — causing a DB exception that
        // rolls back the whole transaction.
        //
        // To do this deterministically, we first create a track row for the
        // same (profileId, curriculumId, trackType) combination *before* the
        // use case runs, using a profile ID we know the use case will get.
        //
        // An easier approach: let the use case try to insert two tracks for
        // the SAME curriculum. That also violates the unique key and rolls back.
        // We achieve that by passing duplicate curriculum IDs.

        // Note: passing the same CurriculumId twice should cause the second
        // track insert to fail on the unique constraint
        // (profileId, curriculumId, trackType), rolling back everything.
        Object? caughtError;
        try {
          await useCase.execute(
            const ProfileCreationCommand(
              accountId: 1,
              displayName: 'ShouldRollback',
              mode: 'adult',
              // Same curriculum twice → unique-key violation on second insert.
              curriculumIds: [CurriculumId.mishnayos, CurriculumId.mishnayos],
            ),
          );
        } catch (e) {
          caughtError = e;
        }

        // The transaction must have thrown.
        expect(caughtError, isNotNull);

        // Assert zero rows in every affected table.
        expect(
          await countRows(db.learnerProfiles),
          0,
          reason: 'profile row must be rolled back',
        );
        expect(
          await countRows(db.curriculumTracks),
          0,
          reason: 'track rows must be rolled back',
        );
        expect(
          await countRows(db.stageDefinitions),
          0,
          reason: 'stage definition rows must be rolled back',
        );
        expect(
          await countRows(db.pointConfigs),
          0,
          reason: 'point config rows must be rolled back',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Pre-flight guard tests
  // ---------------------------------------------------------------------------

  group('execute — pre-flight guards', () {
    test(
      'throws MaxProfilesExceededException when account has 10 profiles',
      () async {
        // Seed 10 profiles directly.
        for (var i = 1; i <= 10; i++) {
          await db.profileDao.insertProfile(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Profile $i',
              mode: 'adult',
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
        }

        expect(
          () => useCase.execute(
            const ProfileCreationCommand(
              accountId: 1,
              displayName: 'Overflow',
              mode: 'adult',
            ),
          ),
          throwsA(isA<MaxProfilesExceededException>()),
        );
      },
    );

    test(
      'throws DuplicateProfileNameException for case-insensitive duplicate',
      () async {
        await useCase.execute(
          const ProfileCreationCommand(
            accountId: 1,
            displayName: 'Ari',
            mode: 'adult',
          ),
        );

        expect(
          () => useCase.execute(
            const ProfileCreationCommand(
              accountId: 1,
              displayName: 'ari', // same name, different casing
              mode: 'child',
            ),
          ),
          throwsA(isA<DuplicateProfileNameException>()),
        );
      },
    );

    test('does not write any rows when a pre-flight guard fires', () async {
      // Fill to the limit.
      for (var i = 1; i <= 10; i++) {
        await db.profileDao.insertProfile(
          LearnerProfilesCompanion.insert(
            accountId: 1,
            displayName: 'Profile $i',
            mode: 'adult',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      // Attempt one more.
      try {
        await useCase.execute(
          const ProfileCreationCommand(
            accountId: 1,
            displayName: 'Too Many',
            mode: 'adult',
          ),
        );
      } catch (_) {}

      // Count should still be exactly 10.
      expect(await countRows(db.learnerProfiles), 10);
    });
  });
}
