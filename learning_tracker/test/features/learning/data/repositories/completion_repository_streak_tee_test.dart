/// Storage-only invariant: [CompletionRepositoryImpl.markComplete] does
/// NOT write a streak_events row any more.
///
/// Streak recording (formerly `CompletionRepositoryImpl._appendStreakEvent`,
/// including its outbox tee) moved to [DriftCompletionStreakRecorder] —
/// see the doc comment on [CompletionOrchestrator] and
/// `completion_streak_recorder_test.dart` (this file's successor for the
/// streak-tee scenarios themselves — Phase 1's local-write + outbox-tee +
/// failure-logging cases) for where that coverage now lives. This file's
/// remaining job is narrower but still load-bearing: prove the repository
/// is genuinely storage-only by driving `markComplete` directly (no
/// orchestrator in the loop) and asserting `streak_events` stays empty.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int profileId;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    final profile = (await db.select(db.learnerProfiles).get()).first;
    profileId = profile.id;
    trackId = await seedTrack(
      db,
      profileId: profileId,
      curriculumId: 'mishnayos',
    );
    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Stage 1',
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );
  });

  tearDown(() async => db.close());

  test('markComplete never writes a streak_events row — storage-only since '
      'the completion-orchestrator lift', () async {
    final repo = CompletionRepositoryImpl(
      database: db,
      activeProfileId: profileId,
    );

    final result = await repo.markComplete(
      const CompletionRequest(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah_Berakhot_1',
        stageId: 1,
        trackType: 'personal',
      ),
    );

    expect(result.completion.sefariaRef, 'Mishnah_Berakhot_1');

    final localStreaks = await db.select(db.streakEvents).get();
    expect(
      localStreaks,
      isEmpty,
      reason:
          'CompletionRepositoryImpl is storage-only now — streak '
          'recording lives in CompletionOrchestrator + '
          'DriftCompletionStreakRecorder, never in the repository.',
    );
  });
}
