// Regression test for R6-19: duplicate-completion detection must include
// curriculumId in the idempotency key.
//
// Two scenarii:
//   A) Same (sefariaRef, stageId, trackType) in TWO different curricula →
//      two distinct completion rows are created (NOT deduped).
//   B) Identical (curriculumId, sefariaRef, stageId, trackType) called twice →
//      still deduped to one row (existing idempotency preserved).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late int learnerId;

  // Helper: creates a track for the given curriculumId and returns its id.
  Future<int> seedTrack(String curriculumId) async {
    final now = DateTime.now().toUtc();
    final row = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: learnerId,
            curriculumId: curriculumId,
            stateChangedAt: now,
            activatedAt: now,
          ),
        );
    return row.id;
  }

  setUp(() async {
    db = createTestDatabase();

    final now = DateTime.now().toUtc();

    // Account + child profile (child earns points, required by markComplete).
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'r619@example.com',
            tier: 'localBorn',
            displayName: 'R619 Tester',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final profileRow = await db
        .into(db.learnerProfiles)
        .insertReturning(
          ProfilesCompanion.insert(
            accountId: 1,
            displayName: 'R619 Learner',
            mode: 'child',
            createdAt: now,
            updatedAt: now,
          ),
        );
    learnerId = profileRow.id;
  });

  tearDown(() => db.close());

  // ── Scenario A ─────────────────────────────────────────────────────────────
  group('R6-19 cross-curriculum dedup', () {
    test(
      'same (sefariaRef, stageId, trackType) under TWO curricula creates two completions',
      () async {
        // Seed a track for each curriculum so _resolveTrackId succeeds.
        await seedTrack('mishnayos');
        await seedTrack('bavli');

        final repoMishnayos = CompletionRepositoryImpl(
          database: db,
          activeProfileId: learnerId,
        );

        // Same logical item studied under Mishnayos…
        final r1 = (await repoMishnayos.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        )).completion;

        // …and the same textual ref under Bavli (different curriculum).
        final repoBavli = CompletionRepositoryImpl(
          database: db,
          activeProfileId: learnerId,
        );
        final r2 = (await repoBavli.markComplete(
          const CompletionRequest(
            curriculumId: 'bavli',
            sefariaRef: 'Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        )).completion;

        // Must be two distinct rows.
        expect(
          r1.id,
          isNot(r2.id),
          reason: 'Cross-curriculum completions must not be deduped',
        );
        expect(r1.curriculumId, 'mishnayos');
        expect(r2.curriculumId, 'bavli');

        // Both rows visible in the DB.
        final all = await db.completionDao.getCompletionsByProfile(learnerId);
        final byRef = all.where((c) => c.sefariaRef == 'Berachot 1:1').toList();
        expect(
          byRef.length,
          2,
          reason: 'Exactly two completion_events rows for this ref',
        );
      },
    );

    // ── Scenario B ─────────────────────────────────────────────────────────
    test(
      'same request within the same curriculum is still deduped to one row',
      () async {
        await seedTrack('mishnayos');

        final repo = CompletionRepositoryImpl(
          database: db,
          activeProfileId: learnerId,
        );

        const req = CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Berachot 1:1',
          stageId: 1,
          trackType: 'personal',
        );

        final first = (await repo.markComplete(req)).completion;
        final second = (await repo.markComplete(req)).completion; // duplicate

        expect(
          second.id,
          first.id,
          reason: 'True duplicate within same curriculum must return same row',
        );

        // DB must have exactly one row.
        final all = await db.completionDao.getCompletionsByProfile(learnerId);
        expect(
          all.where((c) => c.sefariaRef == 'Berachot 1:1').length,
          1,
          reason:
              'Only one completion_events row for intra-curriculum duplicate',
        );
      },
    );
  });
}
