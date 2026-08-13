/// Story acceptance tests for Epic 27 — Story 27.6 (DNI-382).
///
/// The Firestore event repository is the append path; the Firestore streak
/// state repository derives current and maximum streaks from that log.
@Tags(['epic_27', 'story_27_6'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_streak_state_repository.dart';
import 'package:test/test.dart';

const _profileId = '01J00000000000000000000004';
const _uid = 'uid_test_382';

DateTime _utcDay(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

Future<void> _assertKnownSequence(FakeFirebaseFirestore firestore) async {
  final repository = FirestoreStreakEventRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  final sequence = <DateTime>[
    DateTime.utc(2026, 5, 1, 9),
    DateTime.utc(2026, 5, 2, 9),
    DateTime.utc(2026, 5, 3, 9),
    DateTime.utc(2026, 5, 8, 9),
    DateTime.utc(2026, 5, 9, 9),
    DateTime.utc(2026, 5, 10, 9),
  ];
  for (final (index, timestamp) in sequence.indexed) {
    await repository.append(
      eventType: 'completion',
      eventTimestamp: timestamp,
      ulid: '01J000000000000000000000${index + 40}',
    );
  }

  expect(await repository.getAllEvents(), hasLength(sequence.length));
  final container = ProviderContainer(
    overrides: [
      firestoreStreakEventRepositoryProvider.overrideWith(
        (ref) async => repository,
      ),
    ],
  );
  addTearDown(container.dispose);
  final stateProvider = Provider<FirestoreStreakStateRepository>(
    (ref) => FirestoreStreakStateRepository(
      ref: ref,
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 10, 12)),
      dayOf: _utcDay,
    ),
  );
  final state = await container.read(stateProvider).getStreak();
  expect(state.currentStreak, 3);
  expect(state.maxStreak, 3);
  expect(state.lastCompletionDayLocal, DateTime.utc(2026, 5, 10));
}

void main() {
  group('AC1 — Firestore append + reducer reconciliation', () {
    test('known event sequence produces the expected streak state', () async {
      await _assertKnownSequence(FakeFirebaseFirestore());
    });
  });
}
