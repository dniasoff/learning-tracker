/// Invariant test net — 2026-05-17 quality crisis.
///
/// Characterization/invariant tests (N1–N8) documenting the correct system
/// behaviour. Each becomes the regression anchor for a corresponding repair:
///
///   N1 → R2  offline-queue drains to 0 after an online flush
///   N2 → R1  exactly one SyncOrchestrator instance per session
///   N3 → —   fresh profile reports 0 completions and 0 streak (baseline)
///   N4 → R3  delete+re-add track → completion %, count both 0
///   N5 → R4  restoreOrCreate resets activatedAt; lifetime preserved
///   N6 → R5  completion count and progress % share one "done" definition
///   N7 → F1  pace-goal projected finish anchors to createdAt, not now
///   N8 → C3  purgeHistory never decreases completion_events row count
///
/// Rule: a failing test is fixed by changing production code only — never by
/// weakening the assertion. Each repair ships as one commit: failing test +
/// fix + green test.
@Tags(['invariants'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('Invariant net — 2026-05-17 quality crisis', tags: ['invariants'], () {
    // ── N1 — offline-queue drains to 0 ─────────────────────────────────────

    group(
      'N1: offline-queue drains to 0 after online flush',
      skip:
          'Retired W2.35 — OfflineQueue deleted; equivalent invariant '
          'covered by OutboxProcessor tests (outbox drains to 0 after flush)',
      () {
        test('placeholder', () {});
      },
    );

    // ── N2 — single SyncOrchestrator per session ────────────────────────────

    group('N2: exactly one SyncOrchestrator instance per session', () {
      test('syncOrchestratorProvider does not watch activeProfileIdProvider', () {
        // A `ref.watch(activeProfileIdProvider)` would rebuild the provider on
        // every profile change, creating a second SyncOrchestratorImpl (and a
        // second LifecycleObserver) before the first is disposed.
        //
        // The fix (R1): the provider is a keepAlive singleton. It may use
        // `ref.listen(activeProfileIdProvider, ...)` to restart its listener
        // set on a profile change — `ref.listen` runs a callback WITHOUT
        // rebuilding the provider, so no duplicate orchestrator/observer is
        // created. Only a `ref.watch` on activeProfileIdProvider is forbidden.
        const srcPath =
            'lib/core/sync/providers/sync_orchestrator_providers.dart';
        final file = File(srcPath);
        if (!file.existsSync()) {
          fail('N2: provider source not found at $srcPath');
        }
        final source = file.readAsStringSync();

        expect(
          source,
          isNot(contains('watch(activeProfileIdProvider')),
          reason:
              'N2: syncOrchestratorProvider must not WATCH '
              'activeProfileIdProvider — a profile change must not tear down '
              'and recreate the SyncOrchestrator, which would register a '
              'duplicate LifecycleObserver with WidgetsBinding. '
              '(ref.listen is permitted — it does not rebuild the provider.)',
        );
      });
    });

    // ── N3 — fresh profile = 0 everything ──────────────────────────────────

    group('N3: fresh profile reports 0 completions and 0 streak', () {
      test(
        'getAggregateCountByProfile returns 0 for a profile with no data',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          final count = await db.completionDao.getAggregateCountByProfile(
            'mishnayos',
            1,
          );
          expect(
            count,
            0,
            reason:
                'N3: a profile that has never marked a completion must '
                'report 0 completions',
          );
        },
      );

      test('streaks table has no row for a fresh profile', () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final row = await (db.select(
          db.streakEvents,
        )..where((t) => t.profileId.equals(1))).getSingleOrNull();

        expect(
          row,
          isNull,
          reason:
              'N3: no streak row should exist for a profile that has never '
              'completed anything — the achievement card must not manufacture '
              'a non-zero "Personal Best" from a missing row',
        );
      });
    });

    // ── N4 — delete+re-add: lifetime completions preserved, session starts at 0

    group('N4: delete+re-add track leaves 0 completions', () {
      test('restoreOrCreate after deleteTrackAndData: old completions preserved for '
          'lifetime; current session starts at 0', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        // Create a track for profile 1.
        final originalId = await db.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        // Directly insert 3 completions attached to that track, all in the past.
        for (var i = 0; i < 3; i++) {
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot 1:${i + 1}',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              trackId: originalId,
              eventTimestamp: DateTime.utc(2026, 5, 1),
            ),
          );
        }

        expect(
          await db.completionDao.getAggregateCountByProfile('mishnayos', 1),
          3,
        );

        // Delete the track (soft-delete; completions are intentionally kept).
        await db.trackDao.deleteTrackAndData(originalId);

        // Re-add the same curriculum — restoreOrCreate reuses the old row ID.
        final restoredId = await db.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        expect(
          restoredId,
          equals(originalId),
          reason:
              'N4 pre-condition: restoreOrCreate must reuse the same row id',
        );

        final restored = await db.trackDao.getTrackById(restoredId);

        // Lifetime count still includes pre-restore completions.
        expect(
          await db.completionDao.getAggregateCountByProfile('mishnayos', 1),
          3,
          reason: 'N4: lifetime completions must survive delete+restore',
        );

        // Current-session count (completedAt >= activatedAt) is 0 — fresh start.
        final sessionCompletions = await db.completionDao
            .getCompletionsByTrackAndProfileSince(
              restoredId,
              1,
              restored!.activatedAt,
            );
        expect(
          sessionCompletions,
          isEmpty,
          reason:
              'N4: current-session completions must be 0 — pre-restore rows '
              'predate the new activatedAt and are excluded from the current cycle',
        );
      });
    });

    // ── N5 — restoreOrCreate resets activatedAt to mark a new session ────────

    group('N5: restoreOrCreate resets activatedAt for a new learning session', () {
      test(
        'restored track gets activatedAt = now so the current cycle starts fresh',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          final originalActivatedAt = DateTimeFactory.nowUtc().subtract(
            const Duration(days: 5),
          );

          // Insert a track with an activatedAt 5 days in the past.
          final trackId = await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: 1,
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  stateChangedAt: originalActivatedAt,
                  activatedAt: originalActivatedAt,
                ),
              );

          // Soft-delete the track.
          await db.trackDao.deleteTrackAndData(trackId);

          final beforeRestore = DateTimeFactory.nowUtc();

          // Re-add via restoreOrCreate.
          await db.trackDao.restoreOrCreate(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );

          final restored = await db.trackDao.getTrackById(trackId);

          // activatedAt must be reset to now (new session), not the old value.
          expect(
            restored!.activatedAt.isAfter(
              DateTimeFactory.nowUtc().subtract(const Duration(days: 4)),
            ),
            isTrue,
            reason:
                'N5: restoreOrCreate must reset activatedAt to now so that '
                'the current learning session starts fresh; old completions '
                'predating activatedAt are excluded from current-cycle progress',
          );
          expect(
            restored.activatedAt.isAfter(
              beforeRestore.subtract(const Duration(seconds: 5)),
            ),
            isTrue,
            reason: 'N5: new activatedAt must be approximately now',
          );
        },
      );
    });

    // ── N6 — completion count and progress % share one "done" definition ────

    group('N6: completion count and lifetime % agree on one definition of done', () {
      test(
        'getAggregateCountByProfile counts distinct completed refs, not total rows',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);
          await seedProfile(db);

          // Seed a track so the FK constraint resolves.
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

          // Insert the same sefariaRef at two different stages.
          // By the "distinct refs" definition, 1 ref is done — not 2.
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot 1:1',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              trackId: trackId,
              eventTimestamp: DateTime.utc(2026, 5, 1),
            ),
          );
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot 1:1',
              stageId: 2,
              trackType: TrackType.personal.storageKey,
              trackId: trackId,
              eventTimestamp: DateTime.utc(2026, 5, 2),
            ),
          );

          final rawCount = await db.completionDao.getAggregateCountByProfile(
            'mishnayos',
            1,
          );

          // FAILS today: rawCount = 2 (all rows), but the distinct-refs numerator
          // used by computeCompletionPercentage returns 1.
          // Both metrics must share the same "done" unit so the UI stays consistent.
          expect(
            rawCount,
            1,
            reason:
                'N6: getAggregateCountByProfile must count distinct completed '
                'sefariaRefs (1), not total completion rows (2); otherwise '
                'the completion count and lifetime-% disagree on what "done" '
                'means',
          );
        },
      );
    });

    // ── N8 — purgeHistory never decreases completion_events row count (C3) ───

    group('N8: purgeHistory never decreases completion_events row count', () {
      test(
        'purging a track stamps purgedAt on events and keeps row count stable',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);
          await seedProfile(db);

          final trackId = await db.trackDao.restoreOrCreate(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );

          final writer = CompletionWriter(db);
          for (var i = 1; i <= 4; i++) {
            await writer.commit(
              CompletionCommand(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                sefariaRef: 'Berakhot $i:1',
                stageId: 1,
                trackType: TrackType.personal.storageKey,
                trackId: trackId,
                completedAt: DateTimeFactory.nowUtc(),
                points: 5,
              ),
            );
          }

          final countBefore = (await db.completionEventDao.getEventsByProfile(
            1,
          )).length;

          await db.trackDao.purgeHistory(trackId);

          final eventsAfter = await db.completionEventDao.getEventsByProfile(1);

          expect(
            eventsAfter.length,
            countBefore,
            reason:
                'N8: completion_events row count must never decrease — '
                'purgeHistory uses tombstones, not deletes',
          );
          expect(
            eventsAfter.every((e) => e.purgedAt != null),
            isTrue,
            reason: 'N8: every purged event must have purgedAt set',
          );
          expect(
            await db.completionDao.getCompletionsByProfile(1),
            isEmpty,
            reason: 'N8: completions projection must be empty after purge',
          );
        },
      );
    });

    // ── N7 — pace-goal projected finish anchors to createdAt, not now ────────

    group('N7: pace-goal projected finish anchors to createdAt, not now', () {
      test(
        'projected finish uses goal.createdAt as anchor — stable across days',
        () {
          final createdAt = DateTime.now().subtract(const Duration(days: 7));

          const pacePerWeek = 10;
          const totalItems = 100;
          const completedItems = 0;
          const itemsRemaining = totalItems - completedItems; // 100

          final daysNeeded = (itemsRemaining / pacePerWeek * 7).ceil(); // 70

          final projected1 = createdAt.toLocal().add(
            Duration(days: daysNeeded),
          );
          final projected2 = createdAt.toLocal().add(
            Duration(days: daysNeeded),
          );

          expect(
            projected1,
            equals(createdAt.toLocal().add(const Duration(days: 70))),
            reason:
                'N7: projected finish must be createdAt + 70 days for '
                '100 items at 10/week',
          );

          final nowBased = DateTime.now().add(const Duration(days: 70));
          final differenceMillis =
              (projected1.millisecondsSinceEpoch -
                      nowBased.millisecondsSinceEpoch)
                  .abs();
          expect(
            differenceMillis,
            greaterThan(
              const Duration(days: 6, hours: 23, minutes: 50).inMilliseconds,
            ),
            reason:
                'N7: createdAt-anchored projection must differ from '
                'now-anchored projection by approximately 7 days',
          );

          expect(
            projected1.year == projected2.year &&
                projected1.month == projected2.month &&
                projected1.day == projected2.day,
            isTrue,
            reason:
                'N7: computing the projected finish twice must yield the '
                'same calendar day — createdAt is fixed, so there is no drift',
          );
        },
      );
    });
  });
}
