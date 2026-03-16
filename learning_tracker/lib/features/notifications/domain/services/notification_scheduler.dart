import 'package:flutter/material.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';

/// Orchestrates scheduling/cancelling the daily reminder notification.
///
/// Pure logic — no Riverpod dependency. Providers call these methods.
class NotificationScheduler {
  const NotificationScheduler({required this.service});

  final NotificationService service;

  /// Schedule (or reschedule) the daily reminder.
  Future<void> schedule({
    required TimeOfDay time,
    required int taskCount,
    required int curriculumCount,
  }) async {
    final body =
        'You have $taskCount '
        'task${taskCount == 1 ? '' : 's'} across '
        '$curriculumCount curricul${curriculumCount == 1 ? 'um' : 'a'} today';
    await service.scheduleDailyReminder(
      hour: time.hour,
      minute: time.minute,
      body: body,
    );
  }

  /// Cancel the daily reminder.
  Future<void> cancel() async {
    await service.cancelDailyReminder();
  }
}
