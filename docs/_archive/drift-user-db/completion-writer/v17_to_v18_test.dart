/// C3 migration gate — schema v17 → v18.
///
/// Verifies:
///   1. completion_events has the purgedAt nullable column (default null).
///   2. purgeHistory sets purgedAt on the relevant events.
///   3. completion_events row count never decreases after purgeHistory (N8 pre-check).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('v17→v18: purgedAt tombstone on completion_events', () {
    // ── 1. Schema: purgedAt column exists and defaults to null ───────────────

    test('newly appended completion_events have purgedAt = null', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final trackId = await db.trackDao.restoreOrCreate(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos,
      );

      final writer = CompletionWriter(db);
      await writer.commit(
        CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTimeFactory.nowUtc(),
          points: 5,
        ),
      );

      final events = await db.completionEventDao.getEventsByProfile(1);
      expect(events, hasLength(1));
      expect(
        events.first.purgedAt,
        isNull,
        reason: 'C3: active completion events must have purgedAt = null',
      );
    });

    // ── 2. purgeHistory stamps purgedAt — does NOT delete events ────────────

    test(
      'purgeHistory sets purgedAt on events and removes completions projection',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final trackId = await db.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
        );

        final writer = CompletionWriter(db);
        for (var i = 1; i <= 3; i++) {
          await writer.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot $i:1',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: DateTimeFactory.nowUtc(),
              points: 5,
            ),
          );
        }

        final countBefore = (await db.completionEventDao.getEventsByProfile(
          1,
        )).length;
        expect(countBefore, 3);

        await db.trackDao.purgeHistory(trackId);

        final eventsAfter = await db.completionEventDao.getEventsByProfile(1);
        expect(
          eventsAfter.length,
          countBefore,
          reason: 'N8 pre-check: completion_events row count must not decrease',
        );
        expect(
          eventsAfter.every((e) => e.purgedAt != null),
          isTrue,
          reason: 'C3: purgeHistory must stamp purgedAt on all affected events',
        );

        final completionsAfter = await db.completionDao.getCompletionsByProfile(
          1,
        );
        expect(
          completionsAfter,
          isEmpty,
          reason: 'C3: completions projection rows must be removed after purge',
        );
      },
    );
  });
}
