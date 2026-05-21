/// Acceptance test for Plan §F Phase 5 deliverable 6 — stage definitions
/// push via the dedicated `stage_definition` outbox kind, not via the
/// `settings` piggyback.
///
/// Before this change, `StageDefinitionRepositoryImpl._pushStages` called
/// the abstract `pushSettings` callback (kind=`settings`), but the
/// OutboxProcessor had a second `stage_definition` kind + dedicated
/// `pushStageDefinition` gateway method that was dead code. Routing
/// through the dedicated kind gives the gateway the right doc id
/// (`{trackId}_{stageOrder}`) and matches the listener channel.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../helpers/test_database.dart' show seedProfile;

Future<int> _insertTrack(db.UserDatabase database, {int profileId = 1}) async {
  final row = await database
      .into(database.curriculumTracks)
      .insertReturning(
        db.CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos.storageKey,
          stateChangedAt: DateTime.utc(2026, 5, 21),
          activatedAt: DateTime.utc(2026, 5, 21),
        ),
      );
  return row.id;
}

void main() {
  group('Plan §F Phase 5 deliverable 6 — stage_definition outbox kind', () {
    test(
      'StageDefinitionRepositoryImpl push routes through kind=stage_definition '
      '(never kind=settings)',
      () async {
        final database = db.UserDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await seedProfile(database);
        final trackId = await _insertTrack(database);

        // Wire the real OutboxSyncWriteFacade so its
        // `pushStageDefinitions` lands rows in the actual outbox table.
        final facade = OutboxSyncWriteFacade(
          outboxDao: database.outboxDao,
          database: database,
          profileId: 1,
          clock: const SystemLocalDayClock(),
        );

        final repo = StageDefinitionRepositoryImpl(
          stageDao: database.stageDao,
          completionDao: database.completionDao,
          pushStageDefinitions: facade.pushStageDefinitions,
        );

        // initializeDefaults inserts 3 stages but does NOT push. resetToDefaults
        // (and addStage) both push via _pushStages → pushStageDefinitions.
        await repo.initializeDefaults(
          CurriculumId.mishnayos,
          profileId: 1,
          trackId: trackId,
        );
        await repo.resetToDefaults(
          CurriculumId.mishnayos,
          profileId: 1,
          trackId: trackId,
        );

        // Read every row out of the outbox and tally by kind.
        final allRows = await database.select(database.outbox).get();
        final byKind = <String, int>{};
        for (final r in allRows) {
          byKind[r.entityKind] = (byKind[r.entityKind] ?? 0) + 1;
        }

        // The dedicated kind is the ONLY path that should have rows. The
        // old `settings` piggyback must produce zero rows for this flow.
        expect(byKind[OutboxEntityKind.stageDefinition], greaterThan(0));
        expect(byKind[OutboxEntityKind.settings] ?? 0, 0);

        // Every row's entityKey is `{trackId}_{stageOrder}` — the doc id
        // shape the gateway expects.
        final stageRows = allRows.where(
          (r) => r.entityKind == OutboxEntityKind.stageDefinition,
        );
        for (final row in stageRows) {
          expect(
            row.entityKey,
            matches(RegExp(r'^\d+_\d+$')),
            reason: 'doc-id derives from track_id + stage_order',
          );
        }
      },
    );

    test('addStage enqueues exactly one stage_definition row per stage in '
        'the updated set', () async {
      final database = db.UserDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await seedProfile(database);
      final trackId = await _insertTrack(database);

      final facade = OutboxSyncWriteFacade(
        outboxDao: database.outboxDao,
        database: database,
        profileId: 1,
        clock: const SystemLocalDayClock(),
      );

      final repo = StageDefinitionRepositoryImpl(
        stageDao: database.stageDao,
        completionDao: database.completionDao,
        pushStageDefinitions: facade.pushStageDefinitions,
      );

      await repo.initializeDefaults(
        CurriculumId.mishnayos,
        profileId: 1,
        trackId: trackId,
      );

      // Clear the outbox so we observe only the addStage push.
      await database.delete(database.outbox).go();

      // Adding a 4th stage triggers _pushStages → 4 rows enqueued (one
      // per current stage).
      await repo.addStage(
        CurriculumId.mishnayos,
        'Chazara 3',
        profileId: 1,
        trackId: trackId,
        schedule: const DelaySchedule(30),
      );

      final rows = await database.select(database.outbox).get();
      final stageRows = rows.where(
        (r) => r.entityKind == OutboxEntityKind.stageDefinition,
      );
      expect(stageRows, hasLength(4));

      // Every payload carries the stage's natural-key fields so the
      // gateway can derive the deterministic doc id.
      for (final row in stageRows) {
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        expect(payload['track_id'], trackId);
        expect(payload['stage_order'], isA<int>());
        expect(payload['curriculum_id'], CurriculumId.mishnayos.storageKey);
      }
    });
  });
}
