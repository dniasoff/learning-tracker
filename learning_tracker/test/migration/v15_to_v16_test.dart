/// C1 migration gate — schema v15 → v16.
///
/// Verifies:
///   1. completions table has the derived_from_events column (default false).
///   2. New completions written via CompletionWriter get derived_from_events=true.
///   3. Backfill: existing completions whose natural key matches a
///      completion_events row are marked derived_from_events=true by the
///      migration SQL.
///   4. Legacy completions with no matching event keep derived_from_events=false.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../helpers/drift_memory.dart';
import '../helpers/migration_test_helper.dart';

void main() {
  group('v15→v16: derived_from_events column', () {
    // ── 1. Schema state: column exists with correct default ─────────────────

    test(
      'completions table has derived_from_events with default false',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: DateTimeFactory.nowUtc(),
                activatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        // Insert directly into the completions table (bypasses CompletionWriter
        // and completion_events) to simulate a legacy row that predates C1.
        await db
            .into(db.completionEvents)
            .insert(
              CompletionsCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                sefariaRef: 'Berakhot 1:1',
                stageId: 1,
                trackType: TrackType.personal.storageKey,
                trackId: trackId,
                completedAt: DateTime.utc(2026, 5, 1),
                // derivedFromEvents not provided → uses default (false)
              ),
            );

        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(1));
        expect(
          rows.first.derivedFromEvents,
          isFalse,
          reason: 'rows not written by the new writer must default to false',
        );
      },
    );

    // ── 2. New CompletionWriter rows get derived_from_events = true ─────────

    test(
      'CompletionWriter sets derived_from_events = true on new writes',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: DateTimeFactory.nowUtc(),
                activatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        final writer = CompletionWriter(db);
        final result = await writer.commit(
          CompletionCommand(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Berakhot 2:1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            trackId: trackId,
            completedAt: DateTimeFactory.nowUtc(),
            points: 5,
          ),
        );

        expect(result.isNew, isTrue);
        expect(
          result.completion.derivedFromEvents,
          isTrue,
          reason: 'C1: CompletionWriter must tag derived rows as event-sourced',
        );
      },
    );

    // ── 3. CompletionWriter idempotency via completion_events (UNIQUE) ───────

    test(
      'duplicate commit returns isNew=false without writing a second event',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: DateTimeFactory.nowUtc(),
                activatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        final cmd = CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 3:1',
          stageId: 1,
          trackType: TrackType.personal.storageKey,
          trackId: trackId,
          completedAt: DateTimeFactory.nowUtc(),
          points: 5,
        );

        final writer = CompletionWriter(db);
        await writer.commit(cmd);
        final second = await writer.commit(cmd);

        expect(second.isNew, isFalse);

        final events = await db.completionEventDao.getEventsByProfile(1);
        expect(
          events,
          hasLength(1),
          reason: 'C1: dedup must prevent a second event row',
        );
      },
    );

    // ── 4. Migration backfill: openDbAtVersion simulates v15 → v16 ──────────
    //
    // Note: this exercises the FULL migration path from v15 (C1 setup) through
    // v19 (current). The partial schema in v15SchemaForC1() means later
    // migrations that touch other tables (streakEvents, learningLedger, etc.)
    // will skip gracefully — those tables don't exist and alterTable creates
    // them fresh. What we verify is the C1 backfill result on the seeded rows.

    test(
      'migration backfill: existing completion + event gets derived=true; orphan stays false',
      () async {
        final db = openDbAtVersion(15, v15SchemaForC1());
        addTearDown(db.close);

        // Trigger the first open (which runs migrations).
        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(2));

        final berakhot2a = rows.firstWhere(
          (r) => r.sefariaRef == 'Berakhot 2a',
        );
        final berakhot2b = rows.firstWhere(
          (r) => r.sefariaRef == 'Berakhot 2b',
        );

        expect(
          berakhot2a.derivedFromEvents,
          isTrue,
          reason:
              'backfill must set derived_from_events=true when a matching '
              'completion_events row exists',
        );
        expect(
          berakhot2b.derivedFromEvents,
          isFalse,
          reason:
              'completion without a matching event must keep derived_from_events=false',
        );
      },
    );
  });
}
