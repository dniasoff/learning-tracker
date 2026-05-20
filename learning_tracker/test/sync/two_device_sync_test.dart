/// I-5: Two-device sync end-to-end tests.
///
/// Uses two independent in-memory databases (deviceA, deviceB) and a shared
/// stub gateway to simulate the Firestore backend.
///
/// Scenarios covered:
///   S1. Device A marks a completion → appears on Device B after pull.
///   S2. Soft-delete enqueues a track_delete outbox row for push.
///   S3. Same completion from two devices deduplicates to one event.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';

import '../helpers/drift_memory.dart' show inMemoryDb, seedProfile;

void main() {
  group('I-5: two-device sync scenarios', () {
    late UserDatabase deviceA;
    late UserDatabase deviceB;

    setUp(() async {
      deviceA = inMemoryDb();
      deviceB = inMemoryDb();
      await seedProfile(deviceA);
      await seedProfile(deviceB);
    });

    tearDown(() async {
      await deviceA.close();
      await deviceB.close();
    });

    // ── S1: completion on A appears on B after flush+pull ─────────────────

    test(
      'S1: completion on Device A propagates to Device B after sync',
      () async {
        final trackIdA = await deviceA.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
        );
        await deviceB.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
        );

        // Device A marks a completion — outbox row written atomically.
        await CompletionWriter(deviceA).commit(
          CompletionCommand(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Berakhot 1:1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            trackId: trackIdA,
            completedAt: DateTime.utc(2026, 5, 1),
            points: 5,
          ),
        );

        // Simulate push: read completion rows from Device A's outbox.
        final outboxRows = await deviceA.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          1,
        );

        // Simulate pull: ingest each completion event on Device B.
        for (final row in outboxRows) {
          final data = jsonDecode(row.payload) as Map<String, dynamic>;
          await deviceB.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: row.profileId,
              curriculumId: data['curriculum_id'] as String,
              sefariaRef: data['sefaria_ref'] as String,
              stageId: (data['stage_id'] as num).toInt(),
              trackType: data['track_type'] as String,
              eventTimestamp: DateTime.parse(data['completed_at'] as String),
            ),
          );
        }

        final eventsB = await deviceB.completionEventDao.getEventsByProfile(1);
        expect(
          eventsB.any((e) => e.sefariaRef == 'Berakhot 1:1'),
          isTrue,
          reason:
              'S1: completion event must appear on Device B after push+pull',
        );
      },
    );

    // ── S2: soft-delete pushes a track_delete outbox row (I-5) ───────────

    test('S2: deleteTrackAndData enqueues a track_delete outbox row', () async {
      final trackId = await deviceA.trackDao.restoreOrCreate(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos,
      );

      await deviceA.trackDao.deleteTrackAndData(trackId);

      final outboxRows = await deviceA.outboxDao.getPendingByKind('track', 1);
      expect(
        outboxRows.any((r) => r.entityKey.contains('track_delete')),
        isTrue,
        reason:
            'I-5: soft-delete must enqueue track_delete so remote devices sync',
      );
    });

    // ── S3: same completion from two devices deduplicates ────────────────

    test(
      'S3: same completion from two devices collapses to one event',
      () async {
        final trackIdB = await deviceB.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
        );

        final ts = DateTime.utc(2026, 5, 10);
        final cmd = CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 5:1',
          stageId: 1,
          trackType: TrackType.personal.storageKey,
          trackId: trackIdB,
          completedAt: ts,
          points: 5,
        );

        // Device B writes locally.
        await CompletionWriter(deviceB).commit(cmd);

        // Same event arrives from Device A via pull (INSERT OR IGNORE → no-op).
        await deviceB.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Berakhot 5:1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            eventTimestamp: ts,
          ),
        );

        final matching = (await deviceB.completionEventDao.getEventsByProfile(
          1,
        )).where((e) => e.sefariaRef == 'Berakhot 5:1').toList();

        expect(
          matching,
          hasLength(1),
          reason:
              'S3: UNIQUE constraint must collapse duplicate events to one row',
        );
      },
    );
  });
}
