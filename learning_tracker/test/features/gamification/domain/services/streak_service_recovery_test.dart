import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'streak-recovery-uid';
const _profileId = '01J00000000000000000000004';
final _today = DateTime.utc(2026, 5, 10, 12);

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
  test('recovery info reports the current derived streak', () async {
    final (container, repository) = await _harness();
    addTearDown(container.dispose);
    await repository.append(
      eventType: 'completion',
      eventTimestamp: DateTime.utc(2026, 5, 9, 9),
    );
    final info = await container.read(streakServiceProvider).getRecoveryInfo();
    expect(info.wasRecovered, isFalse);
    expect(info.currentStreak, 1);
    expect(info.missedDate, isNull);
  });

  test('non-completion events do not create a streak', () async {
    final (container, repository) = await _harness();
    addTearDown(container.dispose);
    await repository.append(
      eventType: 'manual_reset',
      eventTimestamp: DateTime.utc(2026, 5, 10, 9),
    );
    final state = await container.read(streakServiceProvider).getStreak();
    expect(state.currentStreak, 0);
  });
}
