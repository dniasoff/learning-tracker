// Story 3.5 (DNI-508) AC-7, ruling B12: the OS keeps the scheduled
// catch-up reminders across a reboot because the app declares
// RECEIVE_BOOT_COMPLETED and flutter_local_notifications' boot receiver,
// which re-arms the plugin's persisted schedule on boot. (The reconcile
// on app start is unit-tested in catch_up_reminder_scheduler_test.dart;
// the real `adb reboot` check is release verification, B12.)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('RECEIVE_BOOT_COMPLETED is declared', () {
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
  });

  test('the plugin boot receiver listens for BOOT_COMPLETED', () {
    final receiver = RegExp(
      '<receiver[^>]*ScheduledNotificationBootReceiver[^>]*>(.*?)</receiver>',
      dotAll: true,
    ).firstMatch(manifest);
    expect(receiver, isNotNull);
    expect(
      receiver!.group(1),
      contains('android.intent.action.BOOT_COMPLETED'),
    );
  });

  test('the scheduled-notification receiver that fires a one-shot is '
      'declared', () {
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
      ),
    );
  });
}
