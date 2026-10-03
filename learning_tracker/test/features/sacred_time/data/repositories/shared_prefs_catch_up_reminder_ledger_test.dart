// Story 3.5 (DNI-508): the device-local catch-up reminder ledger — a JSON
// blob in SharedPreferences that survives a restart, and an unreadable one
// is dropped rather than crashing the reconcile.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/shared_prefs_catch_up_reminder_ledger.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatchUpReminderEntry _entry(String key, int id, DateTime fireAt) =>
    CatchUpReminderEntry(
      key: key,
      profileId: '01J8XKQ2M3N4P5R6S7T8V9W0XY',
      id: id,
      fireAtUtc: fireAt,
      copyHash: 4242,
    );

void main() {
  final fireAt = DateTime.utc(2026, 10, 9, 17, 30);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads an empty state when nothing is stored', () async {
    final state = await SharedPrefsCatchUpReminderLedger().read();

    expect(state.pending, isEmpty);
    expect(state.consumed, isEmpty);
  });

  test(
    'write then read round-trips pending entries and consumed keys',
    () async {
      final ledger = SharedPrefsCatchUpReminderLedger();
      await ledger.write(
        CatchUpReminderLedgerState(
          pending: [_entry('k1', 51050, fireAt)],
          consumed: {'old': DateTime.utc(2026, 9, 25, 18)},
        ),
      );

      // A fresh ledger instance reads what the first persisted.
      final state = await SharedPrefsCatchUpReminderLedger().read();

      expect(state.pending, hasLength(1));
      final e = state.pending.single;
      expect(e.key, 'k1');
      expect(e.profileId, '01J8XKQ2M3N4P5R6S7T8V9W0XY');
      expect(e.id, 51050);
      expect(e.fireAtUtc, fireAt);
      expect(e.fireAtUtc.isUtc, isTrue);
      expect(e.copyHash, 4242);
      expect(state.consumed, {'old': DateTime.utc(2026, 9, 25, 18)});
    },
  );

  test('stores under the versioned key and normalises times to UTC', () async {
    final prefs = await SharedPreferences.getInstance();
    await SharedPrefsCatchUpReminderLedger().write(
      CatchUpReminderLedgerState(pending: [_entry('k1', 1, fireAt.toLocal())]),
    );

    final raw = prefs.getString(catchUpReminderLedgerKey)!;
    final json = jsonDecode(raw) as Map<String, Object?>;
    final pending = (json['pending']! as List).single as Map<String, Object?>;
    expect(catchUpReminderLedgerKey, 'catch_up_reminder_ledger_v1');
    expect(pending['fire_at'], fireAt.toIso8601String());
    expect(pending.keys, containsAll(['key', 'profile_id', 'id', 'copy']));
  });

  test('an unreadable ledger is dropped to an empty state', () async {
    SharedPreferences.setMockInitialValues({
      catchUpReminderLedgerKey: '{not json',
    });

    final state = await SharedPrefsCatchUpReminderLedger().read();

    expect(state.pending, isEmpty);
    expect(state.consumed, isEmpty);
  });

  test('a ledger missing a required field is dropped, not half-read', () async {
    SharedPreferences.setMockInitialValues({
      catchUpReminderLedgerKey: jsonEncode({
        'pending': [
          {'key': 'k1'},
        ],
      }),
    });

    final state = await SharedPrefsCatchUpReminderLedger().read();

    expect(state.pending, isEmpty);
  });

  test('decode tolerates absent pending and consumed sections', () {
    final state = decodeCatchUpReminderLedger('{}');

    expect(state.pending, isEmpty);
    expect(state.consumed, isEmpty);
  });

  test('uses the injected preferences accessor', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final ledger = SharedPrefsCatchUpReminderLedger(
      prefs: () async {
        calls++;
        return prefs;
      },
    );

    await ledger.write(CatchUpReminderLedgerState());
    await ledger.read();

    expect(calls, 2);
  });
}
