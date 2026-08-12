/// RA-03 regression guard — recent-activity providers must re-execute when
/// completionCommittedProvider ticks.
///
/// Before the fix, the four `recentActivity*Provider` families only watched
/// `progressLensRefreshTickProvider` (manual pull-to-refresh). They did NOT
/// watch `completionCommittedProvider`, so the Recent Activity charts stayed
/// stale after a live completion until the user manually pulled to refresh.
///
/// After the fix a tick on completionCommittedProvider causes each provider
/// to re-execute with the updated DB state.
///
/// Test strategy: use a real in-memory DB + real production provider bodies
/// (no body override). Seed one completion, record the initial result, write
/// a second completion, tick completionCommittedProvider, re-read the
/// provider and assert the result changed — proving the provider re-fetched
/// reactively without any explicit refresh/invalidate.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show firestoreCompletionRepositoryProvider;
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/recent_activity_providers.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'recent-activity-reactivity-uid';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

// 7-day window containing all seeded completions.
final _start = DateTime.utc(2026, 6, 1);
final _end = DateTime.utc(2026, 6, 7);
final _window = RecentActivityWindow(startDate: _start, endDate: _end);

ProviderContainer _makeContainer(FakeFirebaseFirestore firestore) =>
    ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => FirestoreCompletionRepository(
            firestore: firestore,
            uid: _uid,
            profileId: _profileId,
          ),
        ),
      ],
    );

/// Seeds a live (streak-eligible) completion inside the 7-day window.
Future<void> _seedLiveCompletion(
  FakeFirebaseFirestore firestore,
  DateTime at, {
  String ref = 'Berakhot 2a',
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.bavli,
    sefariaRef: ref,
    stageId: 1,
    completedAt: at,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  group(
    'RA-03: recentActivity providers react to completionCommittedProvider',
    () {
      test(
        'recentActivityLimudimChazarosProvider reflects new completion after '
        'completionCommittedProvider tick (no pull-to-refresh required)',
        () async {
          // Seed one completion so the first read is non-empty.
          await _seedLiveCompletion(firestore, DateTime.utc(2026, 6, 3, 10));

          final container = _makeContainer(firestore);
          addTearDown(container.dispose);

          // Listen to keep the autoDispose provider alive.
          final sub = container.listen(
            recentActivityLimudimChazarosProvider(_window),
            (_, __) {},
          );
          addTearDown(sub.close);

          final first = await container.read(
            recentActivityLimudimChazarosProvider(_window).future,
          );
          final firstTotal = first.fold<int>(0, (acc, d) => acc + d.total);
          // Sanity: our seed is visible.
          expect(firstTotal, greaterThan(0));

          // Write a SECOND completion after the first read — must be picked up.
          await _seedLiveCompletion(
            firestore,
            DateTime.utc(2026, 6, 4, 10),
            ref: 'Berakhot 2b',
          );

          // Signal reactive update — the provider must rebuild automatically.
          container.read(completionCommittedProvider.notifier).increment();
          // Give Riverpod one micro-task to propagate the rebuild.
          await Future<void>.microtask(() {});

          final second = await container.read(
            recentActivityLimudimChazarosProvider(_window).future,
          );
          final secondTotal = second.fold<int>(0, (acc, d) => acc + d.total);

          expect(
            secondTotal,
            greaterThan(firstTotal),
            reason:
                'RA-03: recentActivityLimudimChazarosProvider must reflect the '
                'new completion written between reads without requiring pull-to-'
                'refresh; only completionCommittedProvider.notifier.increment() '
                'was called',
          );
        },
      );

      test(
        'recentActivityStreakDatesProvider reflects new streak date after '
        'completionCommittedProvider tick (no pull-to-refresh required)',
        () async {
          final container = _makeContainer(firestore);
          addTearDown(container.dispose);

          final sub = container.listen(
            recentActivityStreakDatesProvider(_window),
            (_, __) {},
          );
          addTearDown(sub.close);

          // Initial read: no completions → empty set.
          final firstDates = await container.read(
            recentActivityStreakDatesProvider(_window).future,
          );
          expect(firstDates, isEmpty);

          // Write a live completion inside the window.
          await _seedLiveCompletion(firestore, DateTime.utc(2026, 6, 3, 10));

          // Tick.
          container.read(completionCommittedProvider.notifier).increment();
          await Future<void>.microtask(() {});

          final secondDates = await container.read(
            recentActivityStreakDatesProvider(_window).future,
          );

          expect(
            secondDates,
            isNotEmpty,
            reason:
                'RA-03: recentActivityStreakDatesProvider must include the new '
                'streak date after completionCommittedProvider ticks, without '
                'requiring pull-to-refresh',
          );
        },
      );
    },
  );
}
