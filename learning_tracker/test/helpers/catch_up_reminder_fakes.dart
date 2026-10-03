/// Fakes for the Story 3.5 (DNI-508) catch-up reminder tests: an in-memory
/// ledger and a notification port that records every call in order.
library;

import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';

/// One recorded notification call.
sealed class ReminderCall {}

/// A recorded `schedule`.
final class ScheduleCall extends ReminderCall {
  ScheduleCall(this.id, this.profileId, this.fireAtUtc, this.title, this.body);
  final int id;
  final String profileId;
  final DateTime fireAtUtc;
  final String title;
  final String body;

  @override
  String toString() => 'schedule($id, $profileId, $fireAtUtc)';
}

/// A recorded `cancel`.
final class CancelCall extends ReminderCall {
  CancelCall(this.id);
  final int id;

  @override
  String toString() => 'cancel($id)';
}

/// A [CatchUpReminderNotifications] that records calls and simulates the
/// OS's pending set (one per id).
class FakeCatchUpNotifications implements CatchUpReminderNotifications {
  FakeCatchUpNotifications({this.permitted = true});

  /// What [canNotify] answers.
  bool permitted;

  /// Every call, in order.
  final List<ReminderCall> calls = [];

  /// The OS's pending reminders by id.
  final Map<int, ScheduleCall> osPending = {};

  /// How many times [canNotify] was asked.
  int permissionChecks = 0;

  List<ScheduleCall> get schedules => calls.whereType<ScheduleCall>().toList();
  List<CancelCall> get cancels => calls.whereType<CancelCall>().toList();

  @override
  int idFor(String profileId, int slot) =>
      (profileId.codeUnits.fold(0, (a, b) => (a * 31 + b) % 100000) + 1) *
          1000 +
      50 +
      slot;

  @override
  Future<bool> canNotify() async {
    permissionChecks++;
    return permitted;
  }

  @override
  Future<void> schedule({
    required int id,
    required String profileId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async {
    final call = ScheduleCall(id, profileId, fireAtUtc, title, body);
    calls.add(call);
    osPending[id] = call;
  }

  @override
  Future<void> cancel(int id) async {
    calls.add(CancelCall(id));
    osPending.remove(id);
  }
}

/// An in-memory [CatchUpReminderLedger].
class MemoryCatchUpLedger implements CatchUpReminderLedger {
  CatchUpReminderLedgerState state = CatchUpReminderLedgerState();

  @override
  Future<CatchUpReminderLedgerState> read() async => state;

  @override
  Future<void> write(CatchUpReminderLedgerState next) async => state = next;
}
