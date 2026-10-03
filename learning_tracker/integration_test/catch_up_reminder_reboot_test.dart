// Story 3.5 (DNI-508) AC-7 — instrumented: catch-up reminders live in the
// OS's local schedule (no network), a process restart re-arms them under
// the same ids without a duplicate, and a lock end that passed while the
// app was not running is never scheduled late.
//
// Runs on a device or emulator with the real flutter_local_notifications
// plugin and SharedPreferences ledger. The permission check is replaced
// by "granted" so the schedule is observable whatever the emulator's
// notification setting is; no permission is ever requested. The physical
// reboot (`adb reboot`, then the plugin's boot receiver) is release
// verification (ruling B12); the manifest side is
// test/features/sacred_time/catch_up_reminder_boot_config_test.dart.
//
// Run (from learning_tracker/, Android emulator booted):
//   flutter test integration_test/catch_up_reminder_reboot_test.dart -d emulator-5554

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/notifications/notifications.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/shared_prefs_catch_up_reminder_ledger.dart';
import 'package:learning_tracker/features/sacred_time/data/services/catch_up_reminder_gateway_adapter.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FB1';

/// The real gateway adapter with the permission check answered "granted".
class _Granted extends GatewayCatchUpReminderNotifications {
  _Granted(super.gateway);

  @override
  Future<bool> canNotify() async => true;
}

final _history = LearnerSettingsHistory.constant(
  const LearnerSettings(
    profileId: _profileId,
    timeZone: 'America/New_York',
    latitude: 40.0821,
    longitude: -74.2097,
    inIsrael: false,
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  late NotificationGateway gateway;

  setUpAll(() async {
    tz.initializeTimeZones();
    gateway = NotificationGateway(plugin: plugin);
    await gateway.initialize();
  });

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(catchUpReminderLedgerKey);
    await plugin.cancelAll();
  });

  CatchUpReminderScheduler scheduler(DateTime now) => CatchUpReminderScheduler(
    notifications: _Granted(gateway),
    ledger: SharedPrefsCatchUpReminderLedger(),
    clock: () => now,
  );

  Future<CatchUpReminderReconcileResult> run(
    DateTime now, {
    bool rearm = false,
  }) => scheduler(now).reconcile(
    targets: [
      CatchUpReminderTarget(
        profileId: _profileId,
        displayName: 'Avi',
        history: _history,
      ),
    ],
    onDeviceProfileIds: {_profileId},
    copy: (kind, name) =>
        (title: 'Shabbos is over', body: '$name, record what you learnt?'),
    rearm: rearm,
  );

  Future<Set<int>> pendingCatchUpIds() async => {
    for (final r in await plugin.pendingNotificationRequests())
      if (r.payload == '$catchUpReminderPayload:$_profileId') r.id,
  };

  testWidgets('the OS holds every upcoming reminder, offline', (_) async {
    final now = DateTime.now().toUtc();
    await run(now);
    final expected = [
      for (final l in lockWindows(
        _history,
        now,
        now.add(catchUpReminderHorizon),
      ))
        if (l.endUtc.isAfter(now)) l,
    ];
    expect(await pendingCatchUpIds(), hasLength(expected.length));
  });

  testWidgets('a restart (new process, same ledger) re-arms the same ids '
      'without a duplicate', (_) async {
    final now = DateTime.now().toUtc();
    await run(now);
    final before = await pendingCatchUpIds();
    await run(now, rearm: true); // a fresh scheduler, as after a restart
    expect(await pendingCatchUpIds(), before);
  });

  testWidgets('an end that passed while the app was down is not sent late', (
    _,
  ) async {
    final now = DateTime.now().toUtc();
    await run(now);
    final first = lockWindows(
      _history,
      now,
      now.add(catchUpReminderHorizon),
    ).firstWhere((l) => l.endUtc.isAfter(now));
    // The app next starts after that end.
    final later = first.endUtc.add(const Duration(hours: 1));
    final result = await run(later, rearm: true);
    expect(result.scheduled.where((e) => !e.fireAtUtc.isAfter(later)), isEmpty);
    expect(result.consumed, hasLength(1));
  });
}
