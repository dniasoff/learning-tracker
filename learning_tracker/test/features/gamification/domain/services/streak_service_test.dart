import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'streak-service-uid';
const _profileId = '01J00000000000000000000005';
final _today = DateTime.utc(2026, 3, 16, 12);

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

Future<void> _appendDays(
  FirestoreStreakEventRepository repository,
  Iterable<DateTime> days,
) async {
  for (final day in days) {
    await repository.append(eventType: 'completion', eventTimestamp: day);
  }
}

void main() {
  test('reads streak state from the Firestore event log', () async {
    final (container, repository) = await _harness();
    addTearDown(container.dispose);
    await _appendDays(repository, [
      DateTime.utc(2026, 3, 14, 9),
      DateTime.utc(2026, 3, 15, 9),
      DateTime.utc(2026, 3, 16, 9),
    ]);

    final service = container.read(streakServiceProvider);
    final state = await service.getStreak();
    expect(state.currentStreak, 3);
    expect(state.maxStreak, 3);
  });

  test(
    'calendar reads completion days from Firestore without a Drift track id',
    () async {
      final (container, repository) = await _harness();
      addTearDown(container.dispose);
      await _appendDays(repository, [
        DateTime.utc(2026, 3, 10, 9),
        DateTime.utc(2026, 3, 12, 9),
      ]);

      final calendar = await container
          .read(streakServiceProvider)
          .getStreakCalendar(
            startUtc: DateTime.utc(2026, 3, 10),
            endUtc: DateTime.utc(2026, 3, 12, 23),
          );
      expect(calendar, hasLength(2));
    },
  );
}
