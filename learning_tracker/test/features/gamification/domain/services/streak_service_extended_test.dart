import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'streak-extended-uid';
const _profileId = '01J00000000000000000000003';
final _today = DateTime.utc(2026, 4, 10, 12);

Future<(ProviderContainer, FirestoreStreakEventRepository)> _harness() async {
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  final repository = FirestoreStreakEventRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  final container = ProviderContainer(
    overrides: [
      firestoreStreakEventRepositoryProvider.overrideWith(
        (ref) async => repository,
      ),
      streakStateProvider.overrideWith(
        (ref) => StreakStateService(ref: ref, clock: FakeLocalDayClock(_today)),
      ),
    ],
  );
  return (container, repository);
}

void main() {
  test('no event log returns the honest empty state', () async {
    final (container, _) = await _harness();
    addTearDown(container.dispose);
    final state = await container.read(streakServiceProvider).getStreak();
    expect(state.currentStreak, 0);
    expect(state.maxStreak, 0);
  });

  test('a gap resets current streak while retaining max streak', () async {
    final (container, repository) = await _harness();
    addTearDown(container.dispose);
    for (final day in [
      DateTime.utc(2026, 4, 6, 9),
      DateTime.utc(2026, 4, 7, 9),
      DateTime.utc(2026, 4, 10, 9),
    ]) {
      await repository.append(eventType: 'completion', eventTimestamp: day);
    }
    final state = await container.read(streakServiceProvider).getStreak();
    expect(state.currentStreak, 1);
    expect(state.maxStreak, 2);
  });

  test('watchStreak is backed by the Firestore event stream', () async {
    final (container, repository) = await _harness();
    addTearDown(container.dispose);
    final stream = container.read(streakServiceProvider).watchStreak();
    final values = <int>[];
    final subscription = stream.listen(
      (state) => values.add(state.currentStreak),
    );
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    await repository.append(
      eventType: 'completion',
      eventTimestamp: DateTime.utc(2026, 4, 10, 9),
    );
    await Future<void>.delayed(Duration.zero);
    expect(values, contains(1));
  });
}
