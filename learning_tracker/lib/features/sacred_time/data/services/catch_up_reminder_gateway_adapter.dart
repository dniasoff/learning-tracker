/// [CatchUpReminderNotifications] on the shared [NotificationGateway]
/// (Story 3.5, DNI-508 T3): the gateway's catch-up id range, one-shot
/// schedule and cancel, and its permission CHECK — never its request
/// (AC-8).
library;

import 'package:learning_tracker/features/notifications/notifications.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';

/// Adapts [NotificationGateway] to the scheduler's port.
class GatewayCatchUpReminderNotifications
    implements CatchUpReminderNotifications {
  /// Creates the adapter over [gateway].
  GatewayCatchUpReminderNotifications(this._gateway)
    : assert(
        catchUpReminderSlots == catchUpReminderIdSlots,
        'the scheduler slots must match the gateway id range',
      );

  final NotificationGateway _gateway;

  @override
  int idFor(String profileId, int slot) =>
      catchUpReminderIdForProfile(profileId, slot);

  @override
  Future<bool> canNotify() => _gateway.hasPermission();

  @override
  Future<void> schedule({
    required int id,
    required String profileId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) => _gateway.scheduleCatchUpReminder(
    id: id,
    profileId: profileId,
    fireAtUtc: fireAtUtc,
    title: title,
    body: body,
  );

  @override
  Future<void> cancel(int id) => _gateway.cancelCatchUpReminder(id);
}
