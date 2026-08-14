/// Regression test for AUD-notifications-01 (SM-4).
///
/// BEFORE: reminderSyncEffect watched `selectedProfileIdProvider` up front,
/// then later awaited `ref.watch(reminderEnabledProvider.future)` with zero
/// `ref.mounted` guard before the next `ref` touch. If `selectedProfileIdProvider`
/// (a dependency reminderSyncEffect watches) changes while that await is
/// still in flight — a genuine profile switch — the stale in-flight
/// execution resumes past the await and touches `ref` again: the exact
/// `UnmountedRefException` hazard SM-4 guards against.
///
/// AFTER: `if (!ref.mounted) return;` immediately follows that await.
///
/// This test reproduces the scenario against the REAL production provider,
/// mirroring the established pattern in
/// test/features/tutoring/incoming_tutor_grants_reconcile_test.dart
/// (AUD-tutoring-14): a manually-completable gate (independent of any
/// Riverpod-managed subscription, so its completion is unaffected by
/// whatever the dependency swap does to element disposal) holds
/// reminderEnabledProvider's build() open. Swap the watched
/// selectedProfileIdProvider override mid-flight, THEN resolve the gate —
/// the in-flight Future captured before the swap must settle without
/// throwing.
@Tags(['needs_flutter'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz_lib;

class _NoopNotificationGateway implements NotificationGateway {
  @override
  Future<void> cancelBatchRemindersForProfile(String profileId) async {}
  @override
  Future<void> cancelDailyReminderForProfile(String profileId) async {}
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
  @override
  Future<void> scheduleBatchRemindersForProfile({
    required String profileId,
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> scheduleStreakAlertForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
  }) async {}
  @override
  Future<void> cancelStreakAlertForProfile(String profileId) async {}
}

/// A ReminderEnabled whose build() hangs on an externally-held Completer
/// instead of touching SharedPreferences — the completer's own resolution
/// is entirely independent of Riverpod's element/subscription lifecycle, so
/// it stays a valid "pending await" regardless of what a sibling dependency
/// swap does elsewhere in the container (mirrors _PendingRepo in
/// incoming_tutor_grants_reconcile_test.dart, AUD-tutoring-14).
class _GatedReminderEnabled extends ReminderEnabled {
  _GatedReminderEnabled(this._gate);
  final Completer<bool> _gate;

  @override
  Future<bool> build() => _gate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile1 = '01ARZ3NDEKTSV4RRFFQ69G5FB0';
  const profile2 = '01ARZ3NDEKTSV4RRFFQ69G5FB1';

  test('reminderSyncEffect: selectedProfileIdProvider changing while '
      'reminderEnabledProvider.future is still pending settles without '
      'throwing UnmountedRefException (AUD-notifications-01, SM-4)', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _NoopNotificationGateway();
    final gate = Completer<bool>();

    List<Override> overridesFor(String profileId) => [
      selectedProfileIdProvider.overrideWithValue(profileId),
      notificationServiceProvider.overrideWithValue(gateway),
      notificationSchedulerProvider.overrideWithValue(
        NotificationScheduler(service: gateway),
      ),
      isSacredTimeActiveProvider.overrideWithValue(false),
      reminderEnabledProvider.overrideWith(() => _GatedReminderEnabled(gate)),
      // The REBUILT (post-swap) execution is a normal, non-stale run that
      // proceeds past the gate (reminderEnabledProvider re-resolves via
      // real SharedPreferences, default true) — keep it DB-free so it
      // settles quickly rather than reaching a real (unfaked) database.
      allDailyTasksProvider.overrideWith((ref) async => const []),
    ];

    final container = ProviderContainer(overrides: overridesFor(profile1));
    addTearDown(container.dispose);

    // An active listener so the provider actually reacts to the override
    // swap below (a lazy container.read alone would never notice).
    container.listen(reminderSyncEffectProvider, (_, _) {});

    // Kick off the build — it watches selectedProfileIdProvider (profile 1) up
    // front, then suspends at
    // `await ref.watch(reminderEnabledProvider.future)` because the gate
    // hasn't completed yet.
    final future = container.read(reminderSyncEffectProvider.future);
    // Let the build actually reach that await before swapping.
    await Future<void>.delayed(Duration.zero);

    // Profile switch mid-flight: the watched selectedProfileIdProvider
    // value changes, which rebuilds reminderSyncEffect and supersedes the
    // in-flight build above — the exact SM-4 race this function's guard
    // must defend against.
    container.updateOverrides(overridesFor(profile2));

    // Now let the ORIGINAL (now-superseded) build's pending await
    // resolve.
    gate.complete(true);

    // The original in-flight future must resolve (or error) WITHOUT
    // throwing UnmountedRefException when it resumes past the await and
    // touches `ref` again.
    await expectLater(future, completes);
  });
}
