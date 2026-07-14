/// Unit tests for `study_day_toggle_service.dart` — the extracted
/// track-resolution guard and write-then-invalidate ordering helpers behind
/// `study_day_config_screen.dart` (AUD-t-scheduler-02).
@Tags(['scheduler', 'study_day'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/study_day_toggle_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  group('resolveStudyDayTrackId', () {
    test('returns the track id when a track exists', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      final resolved = await resolveStudyDayTrackId(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      expect(resolved, equals(trackId));
    });

    test('returns null when no track exists for the curriculum', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final resolved = await resolveStudyDayTrackId(
        db,
        profileId: 1,
        curriculumId: 'bavli',
      );

      expect(resolved, isNull);
    });
  });

  group('withResolvedStudyDayTrackId (STUDYDAY-COMPANION-10 guard)', () {
    test('invokes onFound with the resolved track id when found', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      int? seen;
      await withResolvedStudyDayTrackId(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
        onFound: (id) async {
          seen = id;
        },
      );

      expect(seen, equals(trackId));
    });

    test('no-ops (never calls onFound) when no track exists — never falls '
        'back to trackId=0', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      var called = false;
      await withResolvedStudyDayTrackId(
        db,
        profileId: 1,
        curriculumId: 'bavli',
        onFound: (id) async {
          called = true;
        },
      );

      expect(
        called,
        isFalse,
        reason:
            'STUDYDAY-COMPANION-10: a missing track must skip the write, '
            'not synthesize trackId=0 and call onFound anyway.',
      );
    });
  });

  group('writeThenInvalidate (STUDYDAY-TOGGLE-RACE-14 ordering)', () {
    test('invalidate runs only after write resolves', () async {
      final events = <String>[];
      final writeCompleter = Completer<void>();

      final future = writeThenInvalidate(
        write: () async {
          await writeCompleter.future;
          events.add('write');
        },
        invalidate: () => events.add('invalidate'),
      );

      // Give the event loop a turn: if invalidate ran synchronously/early
      // (the STUDYDAY-TOGGLE-RACE-14 bug), it would already be recorded here
      // even though the write has not resolved.
      await Future<void>.delayed(Duration.zero);
      expect(
        events,
        isEmpty,
        reason: 'invalidate must not fire before write completes',
      );

      writeCompleter.complete();
      await future;

      expect(
        events,
        equals(['write', 'invalidate']),
        reason:
            'STUDYDAY-TOGGLE-RACE-14: invalidate must run strictly after '
            'the awaited write, never before.',
      );
    });

    test('propagates a write failure without invoking invalidate', () async {
      var invalidated = false;

      await expectLater(
        writeThenInvalidate(
          write: () => Future<void>.error(Exception('write failed')),
          invalidate: () => invalidated = true,
        ),
        throwsA(isException),
      );

      expect(
        invalidated,
        isFalse,
        reason: 'a failed write must not trigger a scheduler invalidation',
      );
    });
  });
}
