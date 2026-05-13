/// Story acceptance tests for Epic 27 — Story 27.6 (DNI-382):
/// Integration tests proving the streak reducer reconciles from the
/// event log and that cloud-restore from `completion_events` recovers
/// streak history on a fresh device.
///
/// Two integration tests:
///   AC1 — Append a known sequence of streak events through
///         `StreakEventLog.append(...)` against an in-memory Drift
///         `UserDatabase`, then verify `StreakReducer.reduce()` produces
///         the expected `(currentStreak, maxStreak)` for a fixed "today".
///   AC2 — Seed `completion_events` documents in a fake Firestore, copy
///         them into the local `completions` table (the path the
///         `PullPipeline` would take), then run the cloud-restore flow
///         (`StreakRestorer.restoreIfEmpty`) and assert the reducer
///         output. One restored `streak_events` row per distinct UTC
///         completion day, with no events on days that had no completion.
@Tags(['epic_27'])
library;

import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/streak/streak_event.dart';
import 'package:learning_tracker/core/streak/streak_event_log.dart';
import 'package:learning_tracker/core/streak/streak_reducer.dart';
import 'package:learning_tracker/core/streak/streak_restorer.dart';
import 'package:learning_tracker/core/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

/// Stable test fixtures.
const _profileId = 1;
const _uid = 'uid_test_382';
const _curriculumId = 'shas-bavli';

/// Inserts the minimal FK rows the `completions` table requires so the
/// cloud-restore path can stand up. `CurriculumTracks` is a hard FK
/// from `completions.trackId`.
Future<int> _seedTrack(UserDatabase db) async {
  await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculumId,
          trackType: 'programmed',
          activatedAt: DateTime.utc(2026, 4, 1),
        ),
      );
  final row = await (db.select(
    db.curriculumTracks,
  )..where((t) => t.profileId.equals(_profileId))).getSingle();
  return row.id;
}

void main() {
  group(
    'Story 27.6 — Integration tests: streak reducer reconciles + cloud restore',
    tags: ['story_27_6'],
    () {
      late UserDatabase db;

      setUp(() => db = inMemoryDb());
      tearDown(() => db.close());

      // ── AC1: reducer reconciles a known event sequence ─────────────────

      test(
        'AC1 — StreakEventLog.append + StreakReducer.reduce produces the '
        'expected (currentStreak, maxStreak)',
        () async {
          final log = StreakEventLog(db);

          // A known sequence on profile 1:
          //   May 1, 2, 3       — three consecutive UTC days   → streak 3
          //   (four-day gap)
          //   May 8, 9, 10      — three more consecutive days  → streak 3
          //
          // Today = May 10 (UTC). currentStreak should reflect the most
          // recent run; maxStreak should be the overall best (tie = 3).
          final sequence = <DateTime>[
            DateTime.utc(2026, 5, 1, 9),
            DateTime.utc(2026, 5, 2, 9),
            DateTime.utc(2026, 5, 3, 9),
            DateTime.utc(2026, 5, 8, 9),
            DateTime.utc(2026, 5, 9, 9),
            DateTime.utc(2026, 5, 10, 9),
          ];
          for (final ts in sequence) {
            await log.append(
              StreakEvent(
                profileId: _profileId,
                eventType: 'completion',
                eventTimestamp: ts,
              ),
            );
          }

          // Read back from the in-memory database and reduce.
          final rows = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(_profileId))).get();
          expect(
            rows,
            hasLength(sequence.length),
            reason: 'every appended event must persist (UNIQUE allows them, '
                'they have distinct eventTimestamps)',
          );
          final events = rows.map(
            (r) => StreakEvent(
              profileId: r.profileId,
              eventType: r.eventType,
              eventTimestamp: r.eventTimestamp,
              clientDeviceId: r.clientDeviceId,
            ),
          );

          final state = const StreakReducer().reduce(
            events,
            today: DateTime.utc(2026, 5, 10),
          );

          expect(state.currentStreak, 3);
          expect(state.maxStreak, 3);
          expect(state.lastCompletionDayUtc, DateTime.utc(2026, 5, 10));
        },
      );

      // ── AC2: cloud restore reconstitutes streak from completion_events ─

      test(
        'AC2 — fresh device with empty streak_events pulls completion_events '
        'from fake Firestore; cloud-restore path computes the correct streak',
        () async {
          // 1. Cloud holds three completion_events documents spanning two
          //    distinct UTC days (one of them has two completions on the
          //    same UTC day to verify the per-day collapse rule).
          final fake = createFakeFirestore(authenticatedUid: _uid);

          final events = <Map<String, dynamic>>[
            {
              'uid': _uid,
              'profile_id': _profileId,
              'curriculum_id': _curriculumId,
              'sefaria_ref': 'Mishnah Berakhot 1',
              'stage_id': 1,
              'track_type': 'programmed',
              'completed_at': DateTime.utc(2026, 5, 9, 8).toIso8601String(),
              'points': 10,
            },
            {
              'uid': _uid,
              'profile_id': _profileId,
              'curriculum_id': _curriculumId,
              'sefaria_ref': 'Mishnah Berakhot 2',
              'stage_id': 1,
              'track_type': 'programmed',
              'completed_at': DateTime.utc(2026, 5, 9, 22).toIso8601String(),
              'points': 10,
            },
            {
              'uid': _uid,
              'profile_id': _profileId,
              'curriculum_id': _curriculumId,
              'sefaria_ref': 'Mishnah Berakhot 3',
              'stage_id': 1,
              'track_type': 'programmed',
              'completed_at': DateTime.utc(2026, 5, 10, 8).toIso8601String(),
              'points': 10,
            },
          ];
          for (final (i, e) in events.indexed) {
            // Doc IDs follow the firestore.rules convention
            // `{uid}_{profileId}_{sefariaRef}_{stageId}_{trackType}`.
            final docId =
                '${e['uid']}_${e['profile_id']}_${e['sefaria_ref']}_${e['stage_id']}_${e['track_type']}__$i';
            await fake.collection('completion_events').doc(docId).set(e);
          }

          // 2. Pull the events from fake Firestore. This is the work the
          //    `PullPipeline` does in production; here we exercise the
          //    storage side directly so the cloud-restore path can be
          //    asserted in isolation.
          final snap = await fake
              .collection('completion_events')
              .where('uid', isEqualTo: _uid)
              .get();
          expect(snap.docs, hasLength(3));

          // 3. Local `streak_events` log starts empty — guarantee the
          //    restore path runs.
          final preExisting = await db.select(db.streakEvents).get();
          expect(preExisting, isEmpty);

          // 4. Mirror the pulled documents into local `completions` (which
          //    is what `PullPipeline` + `CompletionEventMerger` would do
          //    via the MergeStore seam). `StreakRestorer.restoreIfEmpty`
          //    reads from `completions`, not from Firestore directly.
          final trackId = await _seedTrack(db);
          for (final doc in snap.docs) {
            final data = doc.data();
            final completedAt = DateTime.parse(data['completed_at'] as String);
            await db
                .into(db.completions)
                .insert(
                  CompletionsCompanion.insert(
                    profileId: _profileId,
                    curriculumId: data['curriculum_id'] as String,
                    sefariaRef: data['sefaria_ref'] as String,
                    stageId: data['stage_id'] as int,
                    trackType: data['track_type'] as String,
                    trackId: trackId,
                    completedAt: completedAt,
                  ),
                );
          }

          // 5. Run cloud-restore path: empty streak_events → reconstitute
          //    one event per distinct UTC completion day.
          final restorer = StreakRestorer(db);
          await restorer.restoreIfEmpty(profileId: _profileId);

          final restored = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(_profileId))).get();
          expect(
            restored,
            hasLength(2),
            reason: 'three completions across TWO distinct UTC days '
                '→ exactly two streak_events rows',
          );
          // Drift serialises DateTime columns through a local-epoch
          // round-trip; compare UTC instants, not wall-clock fields.
          final utcDays = restored
              .map(
                (r) => DateTime.utc(
                  r.eventTimestamp.toUtc().year,
                  r.eventTimestamp.toUtc().month,
                  r.eventTimestamp.toUtc().day,
                ),
              )
              .toSet();
          expect(
            utcDays,
            {DateTime.utc(2026, 5, 9), DateTime.utc(2026, 5, 10)},
          );

          // 6. Reducer over the restored log must compute the right streak.
          //    May 9 → May 10 is a 2-day consecutive run; today = May 10.
          final provider = StreakStateProvider(
            db: db,
            clock: FakeLocalDayClock(DateTime.utc(2026, 5, 10, 12)),
          );
          final state = await provider.read(profileId: _profileId);

          expect(state.currentStreak, 2);
          expect(state.maxStreak, 2);
          expect(state.lastCompletionDayUtc, DateTime.utc(2026, 5, 10));
        },
      );

      // ── Idempotency safety net for AC2 ─────────────────────────────────

      test(
        'AC2 — calling restoreIfEmpty twice is a no-op (idempotent)',
        () async {
          final trackId = await _seedTrack(db);
          await db
              .into(db.completions)
              .insert(
                CompletionsCompanion.insert(
                  profileId: _profileId,
                  curriculumId: _curriculumId,
                  sefariaRef: 'Mishnah Berakhot 1',
                  stageId: 1,
                  trackType: 'programmed',
                  trackId: trackId,
                  completedAt: DateTime.utc(2026, 5, 9),
                ),
              );

          final restorer = StreakRestorer(db);
          await restorer.restoreIfEmpty(profileId: _profileId);
          await restorer.restoreIfEmpty(profileId: _profileId);

          final rows = await (db.select(
            db.streakEvents,
          )..where((t) => t.profileId.equals(_profileId))).get();
          expect(
            rows,
            hasLength(1),
            reason: 'second restoreIfEmpty must see a non-empty log and bail',
          );
        },
      );
    },
  );
}
