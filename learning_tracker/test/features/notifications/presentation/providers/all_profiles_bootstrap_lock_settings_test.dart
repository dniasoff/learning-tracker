/// DNI-481 AC-5 regression (review finding, Codex High):
///   allProfilesReminderBootstrap did not re-run when an INACTIVE learner's
///   governed / synced lock settings changed while the device stayed
///   unlocked. Its only Sacred-Time dependency was the active-window
///   boolean, so already-scheduled reminder and streak-alert batches kept
///   the OLD lock predicate and could fire inside the NEW lock window.
///
/// FIX: the bootstrap watches the device lock predicate (and the scheduler
/// built from it), so a settings change re-runs the reconcile for every
/// inactive profile against the new predicate.
///
/// The test keeps `isSacredTimeActiveProvider` constant (no lock is live) and
/// changes only the lock predicate, as an inactive learner's settings change
/// does, then asserts both the reminder batch and the streak-alert batch are
/// rebuilt with the newly locked fire times removed.
@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

const _activeProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _inactiveProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FB0';

/// Records the LAST reminder batch and streak-alert predicate per profile.
class _RecordingNotificationGateway implements NotificationGateway {
  final Map<String, List<tz_lib.TZDateTime>> reminderBatches = {};
  final Map<String, bool Function(DateTime utc)?> streakPredicates = {};

  @override
  Future<void> scheduleBatchRemindersForProfile({
    required String profileId,
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {
    reminderBatches[profileId] = List.of(fireTimes);
  }

  @override
  Future<void> scheduleStreakAlertForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
    bool Function(DateTime utc)? isLockedAt,
  }) async {
    streakPredicates[profileId] = isLockedAt;
  }

  @override
  Future<void> cancelBatchRemindersForProfile(String profileId) async {}

  @override
  Future<void> cancelDailyReminderForProfile(String profileId) async {}

  @override
  Future<void> cancelStreakAlertForProfile(String profileId) async {}

  @override
  Future<bool> initialize({
    void Function(String? payload)? onNotificationTap,
  }) => Future.value(false);

  @override
  Future<bool> requestPermission() => Future.value(false);

  @override
  Future<bool> hasPermission() => Future.value(false);

  @override
  Future<void> scheduleDailyReminderForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}
}

/// Stands in for [StreakAlertService] the way production builds it: with
/// the device lock predicate it was constructed with, handed to the gateway
/// on every evaluate (the streak state / completion reads are out of scope).
class _PredicateStreakService implements StreakAlertService {
  _PredicateStreakService(this._gateway, this._profileId, this._isLockedAt);

  final NotificationGateway _gateway;
  final String _profileId;
  final bool Function(DateTime utc) _isLockedAt;

  @override
  Future<StreakAlertOutcome> evaluate({
    required String curriculumId,
    required CurriculumStreak? streak,
    required LearnerSettingsHistory settingsHistory,
    required int hour,
    required int minute,
    String? title,
    String Function(int currentStreak)? localizedBody,
  }) async {
    await _gateway.scheduleStreakAlertForProfile(
      profileId: _profileId,
      hour: hour,
      minute: minute,
      body: 'streak',
      isLockedAt: _isLockedAt,
    );
    return StreakAlertOutcome.scheduled;
  }

  @override
  Future<void> cancelAlert() =>
      _gateway.cancelStreakAlertForProfile(_profileId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The lock predicate, mutable from the test as a learner's settings are.
class _LockPredicate extends Notifier<bool Function(DateTime utc)> {
  @override
  bool Function(DateTime utc) build() =>
      (_) => false;

  // ignore: use_setters_to_change_properties
  void set(bool Function(DateTime utc) predicate) => state = predicate;
}

final _lockPredicateProvider =
    NotifierProvider<_LockPredicate, bool Function(DateTime utc)>(
      _LockPredicate.new,
    );

LearnerProfileEntity _profile(String profileId) {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: profileId,
    displayName: 'Profile $profileId',
    mode: ProfileMode.adult,
    avatar: '',
    createdAt: now,
    updatedAt: now,
  );
}

bool _isSaturday(DateTime utc) => utc.weekday == DateTime.saturday;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('UTC'));
  });

  test('an INACTIVE learner\'s lock settings changing while the device is '
      'unlocked re-runs the bootstrap: newly locked reminder and streak-alert '
      'fire times are removed (DNI-481 AC-5)', () async {
    SharedPreferences.setMockInitialValues({
      NotificationPreferencesRepository.reminderEnabledKey(_inactiveProfileId):
          true,
      NotificationPreferencesRepository.reminderHourKey(_inactiveProfileId): 21,
      NotificationPreferencesRepository.reminderMinuteKey(_inactiveProfileId):
          0,
      NotificationPreferencesRepository.streakAlertEnabledKey(
        _inactiveProfileId,
      ): true,
    });

    final gateway = _RecordingNotificationGateway();
    final container = ProviderContainer(
      overrides: [
        selectedProfileIdProvider.overrideWithValue(_activeProfileId),
        currentAppLocaleProvider.overrideWithValue(const Locale('en')),
        analyticsServiceProvider.overrideWithValue(
          const NullAnalyticsService(),
        ),
        notificationServiceProvider.overrideWithValue(gateway),
        // No lock is live throughout: the active-window boolean never
        // changes, so it cannot be what re-runs the bootstrap.
        isSacredTimeActiveProvider.overrideWithValue(false),
        deviceLockPredicateProvider.overrideWith(
          (ref) => ref.watch(_lockPredicateProvider),
        ),
        profileListStreamProvider.overrideWith(
          (ref) => Stream.value([
            _profile(_activeProfileId),
            _profile(_inactiveProfileId),
          ]),
        ),
        streakAlertServiceProvider(_inactiveProfileId).overrideWith(
          (ref) => _PredicateStreakService(
            ref.watch(notificationServiceProvider),
            _inactiveProfileId,
            ref.watch(deviceLockPredicateProvider),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Keep the autoDispose profile stream and the keepAlive effect observed,
    // as the bootstrapper does in the app.
    final profilesSub = container.listen(profileListStreamProvider, (_, _) {});
    addTearDown(profilesSub.close);
    final effectSub = container.listen(
      allProfilesReminderBootstrapProvider,
      (_, _) {},
    );
    addTearDown(effectSub.close);

    await container.read(allProfilesReminderBootstrapProvider.future);

    final before = gateway.reminderBatches[_inactiveProfileId]!;
    expect(before, hasLength(14));
    expect(before.any((t) => _isSaturday(t.toUtc())), isTrue);
    expect(gateway.streakPredicates[_inactiveProfileId], isNotNull);
    final saturday = before.firstWhere((t) => _isSaturday(t.toUtc())).toUtc();
    expect(gateway.streakPredicates[_inactiveProfileId]!(saturday), isFalse);
    // The active profile is owned by the reactive effects, never here.
    expect(gateway.reminderBatches.containsKey(_activeProfileId), isFalse);

    // The inactive learner's governed settings change: Saturdays are now
    // locked. Nothing else changes.
    container.read(_lockPredicateProvider.notifier).set(_isSaturday);
    await container.pump();
    await container.read(allProfilesReminderBootstrapProvider.future);

    final after = gateway.reminderBatches[_inactiveProfileId]!;
    expect(
      after.where((t) => _isSaturday(t.toUtc())),
      isEmpty,
      reason:
          'The inactive learner\'s reminder batch must be rebuilt against '
          'the NEW lock predicate: no reminder may fire inside the new lock.',
    );
    expect(after, hasLength(12));
    expect(
      gateway.streakPredicates[_inactiveProfileId]!(saturday),
      isTrue,
      reason:
          'The inactive learner\'s streak alerts must be rescheduled with the '
          'NEW lock predicate, so occurrences inside the new lock are dropped.',
    );
  });
}
