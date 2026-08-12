import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/notifications/data/repositories/firestore_notifications_completion_adapter.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'streak-alert-uid';
const _profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ProfileDocIdOverride extends ActiveProfileDocId {
  @override
  String build() => _profileId;
}

class MockNotificationGateway extends Mock implements NotificationGateway {}

/// The fixed "today" used across streak tests: 2026-03-16 UTC.
const _today = (year: 2026, month: 3, day: 16);

/// Insert [count] consecutive `completion` streak events ending yesterday
/// (relative to _today = 2026-03-16), so currentStreak == count.
Future<void> _seedStreak(
  FirestoreStreakEventRepository repository,
  int count,
) async {
  // Last day with a completion is yesterday (3/15). Go back [count] days.
  final base = DateTime.utc(_today.year, _today.month, _today.day - 1);
  for (var i = count - 1; i >= 0; i--) {
    final day = base.subtract(Duration(days: i));
    await repository.append(
      eventType: 'completion',
      eventTimestamp: day.copyWith(hour: 18),
    );
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreStreakEventRepository streakRepository;
  late MockNotificationGateway mockNotificationGateway;
  late StreakAlertService service;
  late DateTime Function() clock;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedProfile(firestore, uid: _uid, profileId: _profileId);
    mockNotificationGateway = MockNotificationGateway();

    // Default clock: noon UTC
    clock = () => DateTime.utc(2026, 3, 16, 12, 0, 0);

    final testDay = DateTime.utc(2026, 3, 16, 12, 0, 0);
    final handles = AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );
    container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => handles),
        activeProfileDocIdProvider.overrideWith(_ProfileDocIdOverride.new),
        notificationServiceProvider.overrideWithValue(mockNotificationGateway),
        analyticsServiceProvider.overrideWithValue(
          const NullAnalyticsService(),
        ),
        streakAlertServiceProvider(_profileId).overrideWith((ref) {
          final completions = FirestoreNotificationsCompletionAdapter(ref: ref);
          return StreakAlertService(
            ref: ref,
            hasCompletionsInRange: completions.hasCompletionsInRange,
            notificationService: ref.watch(notificationServiceProvider),
            profileId: _profileId,
            clock: clock,
            streakClock: FakeLocalDayClock(testDay),
            analytics: ref.watch(analyticsServiceProvider),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    streakRepository = FirestoreStreakEventRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    service = container.read(streakAlertServiceProvider(_profileId));

    // Stub notification service methods (per-profile, H2 fix).
    when(
      () => mockNotificationGateway.scheduleStreakAlertForProfile(
        profileId: any(named: 'profileId'),
        hour: any(named: 'hour'),
        minute: any(named: 'minute'),
        body: any(named: 'body'),
        title: any(named: 'title'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockNotificationGateway.cancelStreakAlertForProfile(any()),
    ).thenAnswer((_) async {});
  });

  group('StreakAlertService', () {
    test('alert fires when streak > 0 and no completions today', () async {
      // Set up a streak of 5: events on 3/11-3/15 (yesterday relative to 3/16)
      await _seedStreak(streakRepository, 5);

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: _profileId,
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
          title: 'Streak at Risk!',
        ),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.cancelStreakAlertForProfile(any()),
      );
    });

    test('alert does NOT fire when completions exist today', () async {
      // Set up a streak of 3: events on 3/13-3/15 (streak alive via yesterday)
      await _seedStreak(streakRepository, 3);

      // Add a completion today.
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileId,
        sefariaRef: 'test_ref',
        trackType: 'review',
        completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(_profileId),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
          title: any(named: 'title'),
        ),
      );
    });

    test('alert does NOT fire when streak is 0', () async {
      // Set up a lapsed streak: last event 6 days ago (gap > 1 → currentStreak=0)
      final oldDay = DateTime.utc(2026, 3, 10, 18, 0, 0);
      await streakRepository.append(
        eventType: 'completion',
        eventTimestamp: oldDay,
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(_profileId),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
          title: any(named: 'title'),
        ),
      );
    });

    test('alert does NOT fire when no streak record exists', () async {
      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(_profileId),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
          title: any(named: 'title'),
        ),
      );
    });

    test('alert body includes correct streak count', () {
      expect(StreakAlertService.buildBody(5), 'Your 5-day streak is at risk!');
      expect(StreakAlertService.buildBody(1), 'Your 1-day streak is at risk!');
      expect(
        StreakAlertService.buildBody(100),
        'Your 100-day streak is at risk!',
      );
    });

    test('onCompletionRecorded cancels the alert', () async {
      await service.onCompletionRecorded();

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(_profileId),
      ).called(1);
    });

    test('scheduleAlert schedules with correct parameters', () async {
      await service.scheduleAlert(hour: 21, minute: 0, currentStreak: 7);

      verify(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: _profileId,
          hour: 21,
          minute: 0,
          body: 'Your 7-day streak is at risk!',
          title: 'Streak at Risk!',
        ),
      ).called(1);
    });
  });
}
