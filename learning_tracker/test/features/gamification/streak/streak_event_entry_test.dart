/// Unit tests for `lib/features/gamification/streak/streak_event_entry.dart`
/// — the pure-Dart `StreakEventEntry` model and its
/// `StreakEventEntryFirestoreCodec.toFirestore`/`streakEventEntryFromFirestore`
/// codec functions. No `fake_cloud_firestore` here: these are plain map
/// round-trips, mirroring `bookmark_entity_test.dart`'s style. Repository-
/// level behavior (doc-id, retry-idempotency, decode leniency in a live
/// collection, pagination) is already covered by
/// `test/data/repositories/firestore_streak_event_repository_test.dart`.
///
/// **`day_utc`/`event_timestamp` are written as ISO-8601 `String`s (via
/// `FirestoreCodec.encodeDateTime`), not raw `DateTime`s — verified NOT a
/// bug for this collection.** `firestore.rules`' `streak_events` SR-3 guard
/// only type-checks a key literally named `created_at`, and only when that
/// key is present at all; this codec never writes a `created_at` key (see
/// the model's own class doc comment and
/// `FirestoreStreakEventRepository`'s "No `Timestamp`-vs-`String` trap
/// here" section), so the guard's "field absent" branch always applies and
/// `day_utc`/`event_timestamp` are never rules-type-checked. This is the
/// opposite of `learning_ledger`'s `completed_at`, which IS gated and MUST
/// stay a raw `DateTime` — see `learning_ledger_entry_test.dart`. The tests
/// below pin the String encoding and the absence of a `created_at` key so a
/// future edit that starts writing `created_at` (which WOULD flip this
/// collection into the gated case) is caught immediately.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_entry.dart';

final _day = DateTime.utc(2026, 4, 10);
final _timestamp = DateTime.utc(2026, 4, 10, 9, 30);

void main() {
  final base = StreakEventEntry(
    ulid: 'ULID00000000000000000001',
    eventType: 'completion',
    dayUtc: _day,
    eventTimestamp: _timestamp,
    clientDeviceId: 'device-1',
  );

  group('round-trip', () {
    test('every field survives toFirestore -> fromFirestore, including '
        'clientDeviceId', () {
      final decoded = streakEventEntryFromFirestore(base.toFirestore());

      expect(decoded.ulid, base.ulid);
      expect(decoded.eventType, base.eventType);
      expect(decoded.dayUtc, base.dayUtc);
      expect(decoded.eventTimestamp, base.eventTimestamp);
      expect(decoded.clientDeviceId, base.clientDeviceId);
    });

    test('clientDeviceId absent round-trips to null, and the key is '
        'omitted from the payload rather than written as null', () {
      final noDevice = StreakEventEntry(
        ulid: 'ULID00000000000000000002',
        eventType: 'day_boundary',
        dayUtc: _day,
        eventTimestamp: _timestamp,
      );

      final payload = noDevice.toFirestore();
      expect(payload, isNot(contains('client_device_id')));

      final decoded = streakEventEntryFromFirestore(payload);
      expect(decoded.clientDeviceId, isNull);
    });
  });

  group('field names match the firestore.rules `streak_events` shape', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      final payload = base.toFirestore();

      expect(payload.keys.toSet(), <String>{
        'ulid',
        'event_type',
        'day_utc',
        'event_timestamp',
        'client_device_id',
      });
    });

    test('never writes created_at — streak_events has no .hasOnly() whitelist, '
        'but this key specifically flips on the SR-3 is-timestamp rules guard '
        '(see the file-level doc comment)', () {
      expect(base.toFirestore(), isNot(contains('created_at')));
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test('toFirestore never writes track_id or a Drift-style id', () {
      final payload = base.toFirestore();
      expect(payload, isNot(contains('track_id')));
      expect(payload, isNot(contains('id')));
    });
  });

  group('day_utc/event_timestamp are ISO-8601 Strings — documented-safe for '
      'this collection, unlike learning_ledger.completed_at', () {
    test('toFirestore encodes both date fields as String, not DateTime', () {
      final payload = base.toFirestore();
      expect(payload['day_utc'], isA<String>());
      expect(payload['event_timestamp'], isA<String>());
    });
  });

  group('streakEventEntryFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'ulid': 'ULID00000000000000000003',
      'event_type': 'completion',
      'day_utc': '2026-01-01T00:00:00.000Z',
      'event_timestamp': '2026-01-01T09:00:00.000Z',
    };

    test('throws FormatException when ulid is missing', () {
      final data = validMap()..remove('ulid');
      expect(
        () => streakEventEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when event_type is missing', () {
      final data = validMap()..remove('event_type');
      expect(
        () => streakEventEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when day_utc is missing', () {
      final data = validMap()..remove('day_utc');
      expect(
        () => streakEventEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when event_timestamp is missing', () {
      final data = validMap()..remove('event_timestamp');
      expect(
        () => streakEventEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('a fully valid map decodes without throwing', () {
      expect(() => streakEventEntryFromFirestore(validMap()), returnsNormally);
    });
  });
}
