/// Story acceptance tests for Epic 25 / Story 25.16 (DNI-337):
/// `core/streak/` — event log + reducer + round-trip sync.
///
/// Scope (mirrors Linear DNI-337):
///   * `StreakEventLog`         — thin `append` wrapper over `streak_events`.
///   * `StreakReducer`          — pure `(events, today) → (current, max)`.
///   * `StreakRestorer`         — reconstitutes events from `completions`
///                                when the local log is empty.
///   * `StreakStateProvider`    — the *only* read path for streak values.
///   * `StreakEventMerger`      — append-only merger (round-trip via sync).
@Tags(['epic_25'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_log.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';
import 'package:learning_tracker/features/gamification/streak/streak_restorer.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

UserDatabase _createDb() => UserDatabase(NativeDatabase.memory());

/// Inserts the minimal FK rows the schema requires so we can write
/// `completions` rows in restore tests.
Future<int> _seedTrack(UserDatabase db, {int profileId = 1}) async {
  await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: 'shas-bavli',
          stateChangedAt: DateTime.utc(2026, 5, 1),
          activatedAt: DateTime.utc(2026, 5, 1),
        ),
      );
  final row = await (db.select(
    db.curriculumTracks,
  )..where((t) => t.profileId.equals(profileId))).getSingle();
  return row.id;
}

Future<void> _seedCompletion(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required DateTime completedAt,
  String sefariaRef = 'Mishnah Berakhot 1',
  int stageId = 1,
}) async {
  await seedCompletion(
    db,
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: 'shas-bavli',
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'programmed',
      trackId: trackId,
      eventTimestamp: completedAt,
    ),
  );
}

void main() {
  group(
    'Story 25.16 — core/streak/ event log + reducer + round-trip sync',
    tags: ['story_25_16'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = _createDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      // ── AC1: StreakEventLog.append ─────────────────────────────────────

      group('AC1 — StreakEventLog.append', () {
        test('appends a single event for a profile', () async {
          final log = StreakEventLog(db);
          await log.append(
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 10, 10),
            ),
          );

          final rows = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(1))).get();
          expect(rows, hasLength(1));
          expect(rows.first.eventType, 'completion');
        });

        test(
          'same (profileId, eventTimestamp, eventType) is idempotent',
          () async {
            final log = StreakEventLog(db);
            final e = StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 10, 10),
            );
            await log.append(e);
            await log.append(e); // second call must NOT throw

            final rows = await (db.select(
              db.streakEvents,
            )..where((t) => t.profileId.equals(1))).get();
            expect(
              rows,
              hasLength(1),
              reason:
                  'UNIQUE (profileId, eventTimestamp, eventType) '
                  'must collapse duplicates',
            );
          },
        );
      });

      // ── AC2: StreakReducer (UTC day boundaries) ───────────────────────

      group('AC2 — StreakReducer uses UTC day boundaries', () {
        test('consecutive UTC days extend the streak', () {
          final events = [
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 8, 22),
            ),
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 9, 6),
            ),
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 10, 6),
            ),
          ];
          final today = DateTime.utc(2026, 5, 10);

          final state = const StreakReducer().reduce(events, today: today);

          expect(state.currentStreak, 3);
          expect(state.maxStreak, 3);
        });

        test('multiple events on the SAME UTC day count as one day', () {
          final events = [
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 10, 6),
            ),
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 10, 23, 59),
            ),
          ];
          final today = DateTime.utc(2026, 5, 10);

          final state = const StreakReducer().reduce(events, today: today);

          expect(state.currentStreak, 1);
        });

        test(
          'a >1-day UTC gap resets currentStreak but maxStreak survives',
          () {
            final events = [
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 1),
              ),
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 2),
              ),
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 3),
              ),
              // 4-day gap.
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 8),
              ),
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 9),
              ),
            ];
            final today = DateTime.utc(2026, 5, 9);

            final state = const StreakReducer().reduce(events, today: today);

            expect(state.currentStreak, 2);
            expect(state.maxStreak, 3);
          },
        );

        test(
          'currentStreak drops to 0 once today is >1 UTC day past last event',
          () {
            final events = [
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 1),
              ),
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 2),
              ),
            ];
            // Today is May 5 — well past yesterday's grace.
            final today = DateTime.utc(2026, 5, 5);

            final state = const StreakReducer().reduce(events, today: today);

            expect(state.currentStreak, 0);
            expect(
              state.maxStreak,
              2,
              reason: 'max should survive even when current resets',
            );
          },
        );

        test(
          'late-evening UTC completion + early-morning UTC completion '
          'on the NEXT UTC day are TWO days, even though they could be the '
          'same local day in some timezones — regression for v1.0.60 bug',
          () {
            // 23:30 UTC and 01:30 UTC the next day — adjacent UTC days.
            final events = [
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 9, 23, 30),
              ),
              StreakEvent(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: DateTime.utc(2026, 5, 10, 1, 30),
              ),
            ];
            final today = DateTime.utc(2026, 5, 10);

            final state = const StreakReducer().reduce(events, today: today);
            expect(state.currentStreak, 2);
          },
        );

        test('empty input → zero streak', () {
          final state = const StreakReducer().reduce(
            <StreakEvent>[],
            today: DateTime.utc(2026, 5, 10),
          );
          expect(state.currentStreak, 0);
          expect(state.maxStreak, 0);
        });
      });

      // ── AC4 + AC6: StreakEventMerger round-trip + UNIQUE collapse ─────

      group('AC4/AC6 — StreakEventMerger round-trip', () {
        test(
          'two devices writing the same UTC-day event collapse to one row',
          () async {
            final merger = StreakEventMerger(db);
            // Both devices generate a `completion` event at the exact same
            // UTC instant. Identical natural key → UNIQUE must dedup.
            final instant = DateTime.utc(2026, 5, 10, 10);
            await merger.merge(
              profileId: 1,
              rows: [
                {
                  'event_type': 'completion',
                  'event_timestamp': instant.toIso8601String(),
                  'client_device_id': 'dev-A',
                },
                {
                  'event_type': 'completion',
                  'event_timestamp': instant.toIso8601String(),
                  'client_device_id': 'dev-B',
                },
              ],
            );

            final rows = await (db.select(
              db.streakEvents,
            )..where((t) => t.profileId.equals(1))).get();
            expect(rows, hasLength(1));
          },
        );

        test('merger inserts unseen rows and ignores duplicates', () async {
          final merger = StreakEventMerger(db);
          await merger.merge(
            profileId: 1,
            rows: [
              {
                'event_type': 'completion',
                'event_timestamp': DateTime.utc(2026, 5, 9).toIso8601String(),
              },
              {
                'event_type': 'completion',
                'event_timestamp': DateTime.utc(2026, 5, 10).toIso8601String(),
              },
            ],
          );
          // Second pull repeats the first row + adds a third.
          await merger.merge(
            profileId: 1,
            rows: [
              {
                'event_type': 'completion',
                'event_timestamp': DateTime.utc(2026, 5, 9).toIso8601String(),
              },
              {
                'event_type': 'completion',
                'event_timestamp': DateTime.utc(2026, 5, 11).toIso8601String(),
              },
            ],
          );

          final rows = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(1))).get();
          expect(rows, hasLength(3));
        });
      });

      // ── AC5: empty-log restore from completions ───────────────────────

      group('AC5 — empty-log restore reconstitutes from completions', () {
        setUp(() async {
          // Seed a second learner profile so profileId=2 completions satisfy FK.
          await db
              .into(db.learnerProfiles)
              .insert(
                LearnerProfilesCompanion.insert(
                  accountId: 1,
                  displayName: 'Test User 2',
                  mode: 'adult',
                  createdAt: DateTime.utc(2026, 1, 1),
                  updatedAt: DateTime.utc(2026, 1, 1),
                ),
              );
        });

        test('one streak_events row per distinct UTC completion day', () async {
          final trackId = await _seedTrack(db);
          // Three completions on two distinct UTC days for profile 1.
          await _seedCompletion(
            db,
            profileId: 1,
            trackId: trackId,
            completedAt: DateTime.utc(2026, 5, 9, 8),
          );
          await _seedCompletion(
            db,
            profileId: 1,
            trackId: trackId,
            completedAt: DateTime.utc(2026, 5, 9, 22),
            sefariaRef: 'Mishnah Berakhot 2',
          );
          await _seedCompletion(
            db,
            profileId: 1,
            trackId: trackId,
            completedAt: DateTime.utc(2026, 5, 10, 8),
            sefariaRef: 'Mishnah Berakhot 3',
          );
          // Profile 2 must not leak into profile 1's restore.
          await _seedCompletion(
            db,
            profileId: 2,
            trackId: trackId,
            completedAt: DateTime.utc(2026, 5, 10, 8),
            sefariaRef: 'Mishnah Berakhot 1',
          );

          await StreakRestorer(db).restoreIfEmpty(profileId: 1);

          final rows = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(1))).get();
          expect(rows, hasLength(2));
          final days = rows
              .map(
                (r) => DateTime.utc(
                  r.eventTimestamp.year,
                  r.eventTimestamp.month,
                  r.eventTimestamp.day,
                ),
              )
              .toSet();
          expect(days, {DateTime.utc(2026, 5, 9), DateTime.utc(2026, 5, 10)});
        });

        test('does NOT overwrite a non-empty streak_events log', () async {
          final trackId = await _seedTrack(db);
          // Pre-existing event from sync.
          await StreakEventLog(db).append(
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 1, 12),
            ),
          );
          await _seedCompletion(
            db,
            profileId: 1,
            trackId: trackId,
            completedAt: DateTime.utc(2026, 5, 9),
          );

          await StreakRestorer(db).restoreIfEmpty(profileId: 1);

          final rows = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(1))).get();
          // The seeded May-1 event is the only row — May-9 was not
          // back-filled because the log was non-empty.
          expect(rows, hasLength(1));
          // Drift serialises `DateTime` columns as a local-epoch second
          // and Dart reads them back as local time; compare the UTC
          // instant rather than the wall-clock representation.
          expect(
            rows.first.eventTimestamp.toUtc(),
            DateTime.utc(2026, 5, 1, 12),
          );
        });
      });

      // ── AC7: bulk-mark-prior sentinel date must not inflate streak ───

      group('AC7 — bulk-mark-prior does not inflate streak', () {
        test(
          'fresh install: bulk-mark-prior with sentinel date yields currentStreak==0',
          () async {
            final trackId = await _seedTrack(db);
            // Simulate what BulkPriorCompletionService writes via the optimised path.
            await _seedCompletion(
              db,
              profileId: 1,
              trackId: trackId,
              completedAt: DateTime.utc(2000, 1, 1), // sentinel historical date
            );

            // StreakRestorer sees empty streak_events → restores from completions.
            final state = await StreakStateProvider(
              db: db,
              clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14, 9)),
            ).read(profileId: 1);

            // A 26-year-old completion must NOT produce a current streak.
            expect(state.currentStreak, 0);
          },
        );
      });

      // ── AC3: StreakStateProvider is the only read path ────────────────

      group('AC3 — StreakStateProvider is the only read path', () {
        test('computes (current, max) end-to-end from streak_events', () async {
          await StreakEventLog(db).append(
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 8, 8),
            ),
          );
          await StreakEventLog(db).append(
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 9, 8),
            ),
          );
          await StreakEventLog(db).append(
            StreakEvent(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 5, 10, 8),
            ),
          );

          final provider = StreakStateProvider(
            db: db,
            clock: FakeLocalDayClock(DateTime.utc(2026, 5, 10, 9)),
          );
          final state = await provider.read(profileId: 1);

          expect(state.currentStreak, 3);
          expect(state.maxStreak, 3);
        });

        test(
          'first read on an empty log auto-restores from completions',
          () async {
            final trackId = await _seedTrack(db);
            await _seedCompletion(
              db,
              profileId: 1,
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 9),
            );
            await _seedCompletion(
              db,
              profileId: 1,
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 10),
              sefariaRef: 'Mishnah Berakhot 2',
            );

            final state = await StreakStateProvider(
              db: db,
              clock: FakeLocalDayClock(DateTime.utc(2026, 5, 10, 12)),
            ).read(profileId: 1);

            expect(state.currentStreak, 2);
            expect(state.maxStreak, 2);
          },
        );
      });
    },
  );
}
