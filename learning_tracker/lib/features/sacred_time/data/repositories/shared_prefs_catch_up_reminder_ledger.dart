/// [CatchUpReminderLedger] in SharedPreferences (Story 3.5, DNI-508):
/// device-local notification identity, never a Firestore write. It holds
/// profile ids, lock starts, notification ids and fire times only — no
/// learner name, curriculum or card content.
library;

import 'dart:convert';

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SharedPreferences key of the ledger.
const String catchUpReminderLedgerKey = 'catch_up_reminder_ledger_v1';

/// SharedPreferences-backed [CatchUpReminderLedger].
class SharedPrefsCatchUpReminderLedger implements CatchUpReminderLedger {
  /// Creates the ledger; [prefs] defaults to the app instance.
  SharedPrefsCatchUpReminderLedger({
    Future<SharedPreferences> Function()? prefs,
  }) : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  @override
  Future<CatchUpReminderLedgerState> read() async {
    final raw = (await _prefs()).getString(catchUpReminderLedgerKey);
    if (raw == null) return CatchUpReminderLedgerState();
    try {
      return decodeCatchUpReminderLedger(raw);
    } on Object catch (e, st) {
      // An unreadable ledger is dropped: its pending ids are re-derived
      // and re-armed by the next reconcile (same slots), so nothing fires
      // twice and nothing is lost but the consumed keys of past locks.
      AppLogger.instance.warning(
        event: 'catch_up_reminder_ledger_unreadable',
        exception: e,
        stackTrace: st,
      );
      return CatchUpReminderLedgerState();
    }
  }

  @override
  Future<void> write(CatchUpReminderLedgerState state) async {
    await (await _prefs()).setString(
      catchUpReminderLedgerKey,
      encodeCatchUpReminderLedger(state),
    );
  }
}

/// The ledger's JSON form.
String encodeCatchUpReminderLedger(CatchUpReminderLedgerState state) =>
    jsonEncode({
      'pending': [
        for (final e in state.pending)
          {
            'key': e.key,
            'profile_id': e.profileId,
            'id': e.id,
            'fire_at': e.fireAtUtc.toUtc().toIso8601String(),
            'copy': e.copyHash,
          },
      ],
      'consumed': {
        for (final MapEntry(:key, :value) in state.consumed.entries)
          key: value.toUtc().toIso8601String(),
      },
    });

/// Parses [encodeCatchUpReminderLedger]'s output; throws on a malformed one.
CatchUpReminderLedgerState decodeCatchUpReminderLedger(String raw) {
  final json = jsonDecode(raw) as Map<String, Object?>;
  final pending = (json['pending'] as List<Object?>? ?? const []).map((o) {
    final m = o! as Map<String, Object?>;
    return CatchUpReminderEntry(
      key: m['key']! as String,
      profileId: m['profile_id']! as String,
      id: m['id']! as int,
      fireAtUtc: DateTime.parse(m['fire_at']! as String).toUtc(),
      copyHash: m['copy']! as int,
    );
  }).toList();
  final consumed = <String, DateTime>{
    for (final MapEntry(:key, :value)
        in (json['consumed'] as Map<String, Object?>? ?? const {}).entries)
      key: DateTime.parse(value! as String).toUtc(),
  };
  return CatchUpReminderLedgerState(pending: pending, consumed: consumed);
}
