/// Unit tests for `lib/data/repositories/points_ledger_entry.dart` — the
/// pure-Dart `PointsLedgerEntry` model and its
/// `PointsLedgerEntryFirestoreCodec.toFirestore`/
/// `pointsLedgerEntryFromFirestore` codec functions. No `fake_cloud_firestore`
/// here: these are plain map round-trips, mirroring
/// `learning_ledger_entry_test.dart`'s style. Repository-level behavior
/// (doc-id, retry-idempotency, decode leniency in a live collection, the
/// derived+clamped balance, the negative-sum warning) is already covered by
/// `test/data/repositories/firestore_points_ledger_repository_test.dart`.
///
/// **`created_at` matters most here.** `firestore.rules`' `points_ledger`
/// SR-3 create guard requires `created_at is timestamp` when the field is
/// present (`match /points_ledger/{entryId}`), and a plain Dart `String` is
/// type `string` in Firestore's eyes, not `timestamp` — the model's own
/// codec doc comment calls this out explicitly. `toFirestore` writes
/// `createdAt.toUtc()` directly (a raw `DateTime`), NOT
/// `FirestoreCodec.encodeDateTime(createdAt)`. Verified below — this is the
/// one field this suite would fail loudly on if a future edit "fixed" it
/// back to the String form.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/points_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

void main() {
  final base = PointsLedgerEntry(
    ulid: 'ULID00000000000000000001',
    entryKind: 'completion',
    delta: 10,
    note: 'Berachos 2:1',
    redemptionUlid: null,
    createdAt: DateTime.utc(2026, 3, 1, 12),
    source: CompletionSource.live,
  );

  group('round-trip', () {
    test('every field survives toFirestore -> fromFirestore', () {
      final decoded = pointsLedgerEntryFromFirestore(base.toFirestore());

      expect(decoded.ulid, base.ulid);
      expect(decoded.entryKind, base.entryKind);
      expect(decoded.delta, base.delta);
      expect(decoded.note, base.note);
      expect(decoded.redemptionUlid, base.redemptionUlid);
      expect(decoded.createdAt, base.createdAt);
      expect(decoded.source, base.source);
    });

    test('a negative delta (debit) round-trips correctly', () {
      final debit = PointsLedgerEntry(
        ulid: 'ULID00000000000000000002',
        entryKind: 'redemption_debit',
        delta: -25,
        note: 'Ice cream',
        redemptionUlid: 'REDEMPTION0000000000000A',
        createdAt: DateTime.utc(2026, 3, 2),
        source: CompletionSource.live,
      );

      final decoded = pointsLedgerEntryFromFirestore(debit.toFirestore());
      expect(decoded.delta, -25);
      expect(decoded.entryKind, 'redemption_debit');
      expect(decoded.redemptionUlid, 'REDEMPTION0000000000000A');
    });

    test('every CompletionSource round-trips via .name', () {
      for (final source in CompletionSource.values) {
        final entry = PointsLedgerEntry(
          ulid: 'ULID0000000000000000SRC${source.index}',
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 3, 1),
          source: source,
        );

        final payload = entry.toFirestore();
        expect(
          payload['source'],
          source.name,
          reason: 'written as CompletionSource.name, not a hand-rolled key',
        );
        expect(pointsLedgerEntryFromFirestore(payload).source, source);
      }
    });
  });

  group('field names match the firestore.rules `points_ledger` shape', () {
    test('toFirestore emits exactly the expected snake_case keys when every '
        'optional field is set', () {
      final withRedemption = PointsLedgerEntry(
        ulid: 'ULID00000000000000000003',
        entryKind: 'redemption_refund',
        delta: 25,
        note: 'Refund: Ice cream',
        redemptionUlid: 'REDEMPTION0000000000000A',
        createdAt: DateTime.utc(2026, 3, 1),
        source: CompletionSource.live,
      );

      expect(withRedemption.toFirestore().keys.toSet(), <String>{
        'ulid',
        'entry_kind',
        'delta',
        'note',
        'redemption_ulid',
        'created_at',
        'source',
      });
    });

    test('note and redemption_ulid are OMITTED entirely (not written as null) '
        'when absent', () {
      final minimal = PointsLedgerEntry(
        ulid: 'ULID00000000000000000004',
        entryKind: 'parent_add',
        delta: 15,
        createdAt: DateTime.utc(2026, 3, 1),
        source: CompletionSource.live,
      );

      final payload = minimal.toFirestore();
      expect(payload.keys.toSet(), <String>{
        'ulid',
        'entry_kind',
        'delta',
        'created_at',
        'source',
      });
      expect(payload, isNot(contains('note')));
      expect(payload, isNot(contains('redemption_ulid')));

      final decoded = pointsLedgerEntryFromFirestore(payload);
      expect(decoded.note, isNull);
      expect(decoded.redemptionUlid, isNull);
    });
  });

  group('created_at is a raw DateTime, NOT an ISO-8601 String — SR-3 '
      '`is timestamp` guard', () {
    test('toFirestore writes created_at as a DateTime', () {
      final payload = base.toFirestore();
      expect(
        payload['created_at'],
        isA<DateTime>(),
        reason:
            'firestore.rules requires created_at is timestamp (when '
            'present) on create; a String value is type string in '
            'Firestore\'s eyes and would fail every append call in '
            'production',
      );
    });

    test('the DateTime is normalised to UTC', () {
      final entry = PointsLedgerEntry(
        ulid: 'ULID00000000000000000005',
        entryKind: 'completion',
        delta: 5,
        createdAt: DateTime.utc(2026, 3, 3, 8),
        source: CompletionSource.live,
      );

      final payload = entry.toFirestore();
      expect((payload['created_at'] as DateTime).isUtc, isTrue);
    });
  });

  group('no forbidden fields (AD-5/MCF-11)', () {
    test('toFirestore never writes profile_id, redemption_id (int FK), or an '
        'autoincrement-style id', () {
      final payload = base.toFirestore();
      expect(payload, isNot(contains('profile_id')));
      expect(payload, isNot(contains('redemption_id')));
      expect(payload, isNot(contains('id')));
    });
  });

  group('pointsLedgerEntryFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'ulid': 'ULID00000000000000000006',
      'entry_kind': 'completion',
      'delta': 10,
      'created_at': DateTime.utc(2026, 3, 1),
      'source': 'live',
    };

    test('throws FormatException when ulid is missing', () {
      final data = validMap()..remove('ulid');
      expect(
        () => pointsLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when entry_kind is missing', () {
      final data = validMap()..remove('entry_kind');
      expect(
        () => pointsLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when delta is missing', () {
      final data = validMap()..remove('delta');
      expect(
        () => pointsLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when created_at is missing', () {
      final data = validMap()..remove('created_at');
      expect(
        () => pointsLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('created_at as a real Firestore Timestamp read-back (already a '
        'DateTime by the time it reaches this function) decodes correctly', () {
      final decoded = pointsLedgerEntryFromFirestore(validMap());
      expect(decoded.createdAt, DateTime.utc(2026, 3, 1));
    });

    test('source defaults to CompletionSource.live when missing — the '
        'fail-SAFE default, mirroring learningLedgerEntryFromFirestore', () {
      final data = validMap()..remove('source');
      final decoded = pointsLedgerEntryFromFirestore(data);
      expect(decoded.source, CompletionSource.live);
    });

    test('an unrecognised source value decodes as CompletionSource.live '
        'rather than throwing', () {
      final data = validMap()..['source'] = 'not-a-real-source';
      final decoded = pointsLedgerEntryFromFirestore(data);
      expect(decoded.source, CompletionSource.live);
    });

    test('note and redemption_ulid default to null when absent', () {
      final decoded = pointsLedgerEntryFromFirestore(validMap());
      expect(decoded.note, isNull);
      expect(decoded.redemptionUlid, isNull);
    });

    test('delta arriving as num (not int) is coerced correctly', () {
      final data = validMap()..['delta'] = 10.0;
      final decoded = pointsLedgerEntryFromFirestore(data);
      expect(decoded.delta, 10);
    });
  });
}
