/// Regression test: STUDYDAY-TOGGLE-WRITE-09 + STUDYDAY-TOGGLE-RACE-14
///
/// STUDYDAY-TOGGLE-WRITE-09 — toggling a study day must persist to Drift and
/// re-derive the schedule (no silent no-op). Verified at the DAO layer: after
/// calling `upsertDayConfig`, `getConfigsByTrack` reflects the new dayType.
///
/// STUDYDAY-TOGGLE-RACE-14 — the scheduler must be invalidated AFTER the DB
/// write, not before. The screen's `_toggleDay` previously called
/// `ref.invalidate(allDailyTasksProvider)` *outside* the `.then()` closure —
/// i.e. synchronously, before `upsertDayConfig` resolved. This caused the
/// scheduler to rebuild from stale data.
///
/// Fix: `study_day_config_screen.dart:_toggleDay` now awaits
/// `writeThenInvalidate` (`study_day_toggle_service.dart`), which runs
/// `invalidate` only once `write` has resolved.
///
/// AUD-t-scheduler-02: the STUDYDAY-TOGGLE-RACE-14 group below drives
/// `writeThenInvalidate` itself — the exact function `_toggleDay` calls —
/// rather than re-simulating the ordering with two DAO reads. If a future
/// edit reintroduces `invalidate` before `write` resolves, this test fails.
@Tags(['scheduler', 'study_day', 'studyday_toggle_write_09'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/scheduler/domain/services/study_day_toggle_service.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── STUDYDAY-TOGGLE-WRITE-09 ─────────────────────────────────────────────

  group('STUDYDAY-TOGGLE-WRITE-09: study-day toggle persists to Drift', () {
    test(
      'upsertDayConfig writes study day and getConfigsByTrack reflects it',
      () async {
        final trackId = await seedTrack(db, profileId: 1);

        // Simulate the toggle: set Monday (dayOfWeek=1) to 'review'.
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          dayOfWeek: 1,
          dayType: 'review',
        );

        final configs = await db.studyDayConfigDao.getConfigsByTrack(trackId);
        expect(configs, hasLength(1));
        expect(configs.first.dayOfWeek, equals(1));
        expect(
          configs.first.dayType,
          equals('review'),
          reason:
              'STUDYDAY-TOGGLE-WRITE-09: toggle to review must persist; '
              'getConfigsByTrack must reflect the new dayType immediately.',
        );
      },
    );

    test(
      'upsert is idempotent: toggling the same day twice yields the last value',
      () async {
        final trackId = await seedTrack(db, profileId: 1);

        // Toggle Monday to review, then back to study.
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          dayOfWeek: 1,
          dayType: 'review',
        );
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          dayOfWeek: 1,
          dayType: 'study',
        );

        final configs = await db.studyDayConfigDao.getConfigsByTrack(trackId);
        expect(configs, hasLength(1));
        expect(
          configs.first.dayType,
          equals('study'),
          reason: 'second upsert (study) overwrites the first (review)',
        );
      },
    );

    test(
      'getConfigsByTrack returns configs for the correct track only',
      () async {
        final trackId1 = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'mishnayos',
        );
        final trackId2 = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'bavli',
        );

        // Write review config only for track2.
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId2,
          dayOfWeek: 5,
          dayType: 'review',
        );

        // Track1 must have no configs of its own.
        final configs1 = await db.studyDayConfigDao.getConfigsByTrack(trackId1);
        expect(
          configs1,
          isEmpty,
          reason: "track1's query must not return track2's configs",
        );

        // Track2 must have the config we wrote.
        final configs2 = await db.studyDayConfigDao.getConfigsByTrack(trackId2);
        expect(configs2, hasLength(1));
        expect(configs2.first.dayType, equals('review'));
      },
    );
  });

  // ── STUDYDAY-TOGGLE-RACE-14 ───────────────────────────────────────────────
  //
  // The race was: _toggleDay called ref.invalidate BEFORE the async DB write
  // completed, causing the scheduler to rebuild from stale study-day data.
  // The fix extracted the ordering into `writeThenInvalidate`
  // (study_day_toggle_service.dart), which `_toggleDay` now awaits. These
  // tests drive that exact function — not a re-derivation of the ordering —
  // so a future edit that reintroduces the race is caught here.

  group(
    'STUDYDAY-TOGGLE-RACE-14: writeThenInvalidate ordering — the real function _toggleDay calls',
    () {
      test('invalidate is not called until the awaited write resolves, using a '
          'real DB write', () async {
        final trackId = await seedTrack(db, profileId: 1);
        var invalidateCalled = false;

        await writeThenInvalidate(
          write: () => db.studyDayConfigDao.upsertDayConfig(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackId: trackId,
            dayOfWeek: 3,
            dayType: 'review',
          ),
          invalidate: () => invalidateCalled = true,
        );

        // By the time writeThenInvalidate resolves, the DB write must
        // already be durable AND invalidate must have already fired.
        final configs = await db.studyDayConfigDao.getConfigsByTrack(trackId);
        expect(
          configs.map((c) => c.dayType).toList(),
          contains('review'),
          reason:
              'the write must have completed before writeThenInvalidate '
              'returns',
        );
        expect(invalidateCalled, isTrue);
      });

      test('invalidate never fires before an in-flight write resolves '
          '(would reintroduce the stale-scheduler race)', () async {
        final events = <String>[];
        final writeCompleter = Completer<void>();

        final future = writeThenInvalidate(
          write: () async {
            await writeCompleter.future;
            events.add('write');
          },
          invalidate: () => events.add('invalidate'),
        );

        // Give the event loop a turn without resolving the write. If
        // invalidate fired synchronously/early (the STUDYDAY-TOGGLE-RACE-14
        // bug), it would already be recorded here.
        await Future<void>.delayed(Duration.zero);
        expect(
          events,
          isEmpty,
          reason:
              'STUDYDAY-TOGGLE-RACE-14: invalidate must not fire before '
              'the awaited write completes.',
        );

        writeCompleter.complete();
        await future;

        expect(events, equals(['write', 'invalidate']));
      });
    },
  );
}
