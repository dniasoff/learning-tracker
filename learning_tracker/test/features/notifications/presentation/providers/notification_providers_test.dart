@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _testProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

ProviderContainer _makeContainer() => ProviderContainer(
  overrides: [selectedProfileIdProvider.overrideWithValue(_testProfileId)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // All per-profile keys are explicitly scoped to this ULID in the test
  // container, matching the production providers' selected-profile watch.

  group('ReminderTime', () {
    test('defaults to 7:00 PM', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      // AUD-notifications-02: reminderTimeProvider is an AsyncNotifier that
      // genuinely awaits SharedPreferences — await `.future` for the settled
      // value instead of reading the (removed) hardcoded synchronous default.
      final time = await container.read(reminderTimeProvider.future);
      expect(time.hour, 19);
      expect(time.minute, 0);
    });

    test('loads saved time from SharedPreferences (per-profile key)', () async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderHourKey(_testProfileId): 8,
        NotificationPreferencesRepository.reminderMinuteKey(_testProfileId): 30,
      });
      final container = _makeContainer();
      addTearDown(container.dispose);

      final time = await container.read(reminderTimeProvider.future);
      expect(time.hour, 8);
      expect(time.minute, 30);
    });

    test('setTime persists to per-profile SharedPreferences key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(reminderTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 6, minute: 15));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.reminderHourKey(_testProfileId),
        ),
        6,
      );
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.reminderMinuteKey(_testProfileId),
        ),
        15,
      );
    });
  });

  group('ReminderEnabled', () {
    test('defaults to true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(reminderEnabledProvider.future), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      // Await the settled default before toggling (toggle() flips whatever
      // `state.value` currently holds — awaiting avoids racing the in-flight
      // AsyncNotifier build()).
      await container.read(reminderEnabledProvider.future);
      await container.read(reminderEnabledProvider.notifier).toggle();

      expect(container.read(reminderEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.reminderEnabledKey(_testProfileId),
        ),
        isFalse,
      );
    });
  });

  group('StreakAlertEnabled', () {
    test('defaults to true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(streakAlertEnabledProvider.future), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(streakAlertEnabledProvider.future);
      await container.read(streakAlertEnabledProvider.notifier).toggle();

      expect(container.read(streakAlertEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(
            _testProfileId,
          ),
        ),
        isFalse,
      );
    });
  });

  group('StreakAlertTime', () {
    test('defaults to 9:00 PM', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      final time = await container.read(streakAlertTimeProvider.future);
      expect(time.hour, 21);
      expect(time.minute, 0);
    });

    test('setTime persists to per-profile SharedPreferences key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(streakAlertTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 22, minute: 30));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.streakAlertHourKey(_testProfileId),
        ),
        22,
      );
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.streakAlertMinuteKey(
            _testProfileId,
          ),
        ),
        30,
      );
    });
  });

  group('RewardNotificationEnabled', () {
    test('defaults to true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(rewardNotificationEnabledProvider.future),
        isTrue,
      );
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(rewardNotificationEnabledProvider.future);
      await container.read(rewardNotificationEnabledProvider.notifier).toggle();

      expect(container.read(rewardNotificationEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(
            _testProfileId,
          ),
        ),
        isFalse,
      );
    });
  });
  group("today's learning is read from LearnerState (DNI-482 AC-5)", () {
    // Tue 2026-09-08, 12:00Z, for the UTC no-location learner: unlocked,
    // alert at 21:00. The main-track streak was last kept yesterday.
    final now = DateTime.utc(2026, 9, 8, 12);
    final scope = c0Scope();

    LearningEvent learnToday({String source = LearningEvent.sourceMain}) =>
        LearningEvent.learn(
          id: engineUlid(1),
          curriculumId: engineCurriculum,
          ref: 'Mishnah Berakhot 1:1',
          source: source,
          dateState: DateState.dated,
          learnedOn: '2026-09-08',
          recordedAt: DateTime.utc(2026, 9, 8, 9),
          actor: parentActor,
        );

    Future<(List<String>, int)> runEffect({
      required List<LearningEvent> counted,
      Set<String> lockIgnored = const {},
    }) async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.streakAlertEnabledKey(profileUlid):
            true,
        NotificationPreferencesRepository.streakAlertHourKey(profileUlid): 21,
        NotificationPreferencesRepository.streakAlertMinuteKey(profileUlid): 0,
      });
      final alerts = _DoneTodayAlerts();
      var completionReads = 0;
      final container = ProviderContainer(
        overrides: [
          selectedProfileIdProvider.overrideWithValue(profileUlid),
          currentAppLocaleProvider.overrideWithValue(const Locale('en')),
          streakAlertServiceProvider(profileUlid).overrideWith(
            (ref) => StreakAlertService(
              notifications: alerts,
              markers: _DoneTodayMarkers(),
              profileId: profileUlid,
              clock: () => now,
            ),
          ),
          activeLearnerScopeProvider.overrideWith((ref) async => scope),
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.value(
              fakeLearnerState(
                nowUtc: now,
                today: '2026-09-08',
                countedLearns: counted,
                countedEventIds: {for (final e in counted) e.id},
                lockIgnoredEventIds: lockIgnored,
                curricula: {
                  engineCurriculum: FakeCurriculumState(
                    curriculumId: engineCurriculum,
                    streak: const CurriculumStreak(
                      current: 3,
                      best: 3,
                      lastDay: '2026-09-07',
                    ),
                  ),
                },
              ),
            ),
          ),
          learnerLockSettingsProvider.overrideWith(
            (ref, _) => Stream.value(c0SettingsHistory()),
          ),
          // The retired completion read must never be reached.
          firestoreCompletionRepositoryProvider.overrideWith((ref) async {
            completionReads++;
            throw StateError('completions are retired (R11)');
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(streakAlertSyncEffectProvider.future);
      return (alerts.scheduled, completionReads);
    }

    test('counted learning today (any source) means done: no alert', () async {
      final (scheduled, reads) = await runEffect(
        counted: [learnToday(source: engineUlid(900))],
      );
      expect(scheduled, isEmpty);
      expect(reads, 0);
    });

    test('no counted learning today means the streak is at risk', () async {
      final (scheduled, reads) = await runEffect(counted: const []);
      expect(scheduled, [engineCurriculum]);
      expect(reads, 0);
    });

    test('a voided or lock-ignored event is not in the counted set, so it '
        'never marks today done', () async {
      // The engine leaves voided and lock-ignored events out of
      // countedLearns; the projection reads nothing else.
      final (scheduled, reads) = await runEffect(
        counted: const [],
        lockIgnored: {engineUlid(1)},
      );
      expect(scheduled, [engineCurriculum]);
      expect(reads, 0);
    });
  });
}

class _DoneTodayAlerts implements StreakAlertNotifications {
  final scheduled = <String>[];

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async => scheduled.add(curriculumId);

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) async {}

  @override
  Future<void> cancelAll(String profileId) async {}
}

class _DoneTodayMarkers implements StreakAlertMarkers {
  final _markers = <String, String>{};

  @override
  Future<String?> read(String profileId, String curriculumId) async =>
      _markers['$profileId/$curriculumId'];

  @override
  Future<void> write(
    String profileId,
    String curriculumId,
    String marker,
  ) async => _markers['$profileId/$curriculumId'] = marker;

  @override
  Future<void> clear(String profileId, String curriculumId) async =>
      _markers.remove('$profileId/$curriculumId');

  @override
  Future<void> clearAll(String profileId) async => _markers.clear();
}
