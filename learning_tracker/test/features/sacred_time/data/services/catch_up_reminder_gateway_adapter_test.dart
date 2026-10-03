// Story 3.5 (DNI-508 T3): the scheduler's notification port over the shared
// NotificationGateway — gateway id range, one-shot schedule, cancel, and the
// permission CHECK (never a request, AC-8).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/notifications.dart';
import 'package:learning_tracker/features/sacred_time/data/services/catch_up_reminder_gateway_adapter.dart';

class _RecordingGateway extends NotificationGateway {
  bool permission = true;
  int permissionChecks = 0;
  int requests = 0;
  final List<Map<String, Object?>> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<bool> hasPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<bool> requestPermission() async {
    requests++;
    return true;
  }

  @override
  Future<void> scheduleCatchUpReminder({
    required int id,
    required String profileId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async {
    scheduled.add({
      'id': id,
      'profileId': profileId,
      'fireAtUtc': fireAtUtc,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> cancelCatchUpReminder(int id) async => cancelled.add(id);
}

void main() {
  const profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';
  late _RecordingGateway gateway;
  late GatewayCatchUpReminderNotifications adapter;

  setUp(() {
    gateway = _RecordingGateway();
    adapter = GatewayCatchUpReminderNotifications(gateway);
  });

  test('idFor is the gateway catch-up id of the profile and slot', () {
    for (var slot = 0; slot < catchUpReminderIdSlots; slot++) {
      expect(
        adapter.idFor(profile, slot),
        catchUpReminderIdForProfile(profile, slot),
      );
    }
  });

  test('idFor rejects a slot outside the gateway range', () {
    expect(
      () => adapter.idFor(profile, catchUpReminderIdSlots),
      throwsRangeError,
    );
  });

  test('canNotify checks the permission and never requests it', () async {
    expect(await adapter.canNotify(), isTrue);
    gateway.permission = false;
    expect(await adapter.canNotify(), isFalse);

    expect(gateway.permissionChecks, 2);
    expect(gateway.requests, 0);
  });

  test('schedule forwards every field to the gateway one-shot', () async {
    final fireAt = DateTime.utc(2026, 10, 9, 17, 30);

    await adapter.schedule(
      id: 51051,
      profileId: profile,
      fireAtUtc: fireAt,
      title: 'Shabbos has ended',
      body: 'Avi',
    );

    expect(gateway.scheduled, [
      {
        'id': 51051,
        'profileId': profile,
        'fireAtUtc': fireAt,
        'title': 'Shabbos has ended',
        'body': 'Avi',
      },
    ]);
  });

  test('cancel forwards the id to the gateway', () async {
    await adapter.cancel(51051);

    expect(gateway.cancelled, [51051]);
  });
}
