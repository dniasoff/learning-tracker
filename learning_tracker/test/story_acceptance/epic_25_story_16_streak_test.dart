/// Story acceptance tests for the Firestore-backed streak log and reducer.
@Tags(['epic_25', 'story_25_16'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_streak_state_repository.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';
import 'package:test/test.dart';

import '../helpers/firestore_fixtures.dart';

const _uid = 'uid_story_25_16';
const _profileId = '01J00000000000000000000004';

DateTime _utcDay(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

Future<StreakState> _readState(
  FakeFirebaseFirestore firestore, {
  required DateTime now,
}) async {
  final eventRepository = FirestoreStreakEventRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  final container = ProviderContainer(
    overrides: [
      firestoreStreakEventRepositoryProvider.overrideWith(
        (ref) async => eventRepository,
      ),
    ],
  );
  addTearDown(container.dispose);
  final provider = Provider<FirestoreStreakStateRepository>(
    (ref) => FirestoreStreakStateRepository(
      ref: ref,
      clock: FakeLocalDayClock(now),
      dayOf: _utcDay,
    ),
  );
  return container.read(provider).getStreak();
}

void main() {
  group('AC1 — Firestore streak-event append', () {
    test('appends and reads one event for a ULID profile path', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStreakEventRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );

      final event = await repository.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 5, 10, 10),
        ulid: '01J00000000000000000000006',
      );

      expect(event.eventType, 'completion');
      expect(event.dayUtc, DateTime.utc(2026, 5, 10));
      expect(await repository.getAllEvents(), hasLength(1));
    });

    test('retrying the same ULID is idempotent', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStreakEventRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      const ulid = '01J00000000000000000000007';
      final timestamp = DateTime.utc(2026, 5, 10, 10);

      await repository.append(
        eventType: 'completion',
        eventTimestamp: timestamp,
        ulid: ulid,
      );
      await repository.append(
        eventType: 'completion',
        eventTimestamp: timestamp,
        ulid: ulid,
      );

      expect(await repository.getAllEvents(), hasLength(1));
    });
  });

  group('AC2 — streak state reducer uses local-day buckets', () {
    test('consecutive days produce current and maximum streaks', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStreakEventRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      for (final (index, day) in [
        DateTime.utc(2026, 5, 8, 12),
        DateTime.utc(2026, 5, 9, 12),
        DateTime.utc(2026, 5, 10, 12),
      ].indexed) {
        await repository.append(
          eventType: 'completion',
          eventTimestamp: day,
          ulid: '01J000000000000000000000${index + 10}',
        );
      }

      final state = await _readState(
        firestore,
        now: DateTime.utc(2026, 5, 10, 12),
      );
      expect(state.currentStreak, 3);
      expect(state.maxStreak, 3);
    });

    test('duplicate events on one day count as one day', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStreakEventRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      await repository.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 5, 10, 10),
        ulid: '01J00000000000000000000013',
      );
      await repository.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 5, 10, 14),
        ulid: '01J00000000000000000000014',
      );

      final state = await _readState(
        firestore,
        now: DateTime.utc(2026, 5, 10, 12),
      );
      expect(state.currentStreak, 1);
    });

    test('a gap resets currentStreak while maxStreak survives', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStreakEventRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      for (final (index, day) in [
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 2),
        DateTime.utc(2026, 5, 3),
        DateTime.utc(2026, 5, 8),
        DateTime.utc(2026, 5, 9),
      ].indexed) {
        await repository.append(
          eventType: 'completion',
          eventTimestamp: day,
          ulid: '01J000000000000000000000${index + 20}',
        );
      }

      final state = await _readState(firestore, now: DateTime.utc(2026, 5, 9));
      expect(state.currentStreak, 2);
      expect(state.maxStreak, 3);
    });

    test('empty input produces zero streak', () async {
      final state = await _readState(
        FakeFirebaseFirestore(),
        now: DateTime.utc(2026, 5, 10),
      );
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
    });
  });

  group('AC7 — bulk-mark-prior sentinel does not inflate streak', () {
    test(
      'historical sentinel completion is not a current streak event',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
          completedAt: DateTime.utc(2000, 1, 1),
        );

        final completionRepository = FirestoreCompletionRepository(
          firestore: firestore,
          uid: _uid,
          profileId: _profileId,
        );
        final completions = await completionRepository
            .getCompletionsForCurriculum(CurriculumId.mishnayos);
        expect(completions.single.completedAt, DateTime.utc(2000, 1, 1));

        final state = await _readState(
          firestore,
          now: DateTime.utc(2026, 5, 14, 9),
        );
        expect(state.currentStreak, 0);
      },
    );
  });

  group('AC3 — Firestore streak-state read path', () {
    test('reads current and maximum state from the event repository', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStreakEventRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      for (final (index, day) in [
        DateTime.utc(2026, 5, 8, 8),
        DateTime.utc(2026, 5, 9, 8),
        DateTime.utc(2026, 5, 10, 8),
      ].indexed) {
        await repository.append(
          eventType: 'completion',
          eventTimestamp: day,
          ulid: '01J000000000000000000000${index + 30}',
        );
      }

      final state = await _readState(
        firestore,
        now: DateTime.utc(2026, 5, 10, 9),
      );
      expect(state.currentStreak, 3);
      expect(state.maxStreak, 3);
    });
  });
}
