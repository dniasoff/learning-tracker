/// Unit tests for [FirestoreCodec] — the shared DateTime/int/bool parser
/// transitively exercised by every codec's decode() path.
///
/// AUD-core-sync-16: firestore_codec.dart had zero direct test coverage
/// despite being the shared parsing primitive for all 15 entity codecs.
/// A regression here would silently corrupt every entity kind's pull with
/// nothing to catch it — this file is the direct-unit backstop.
///
/// AG-5 (AUD-app-05): this is also the exhaustive unit-level home AG-5's
/// test-mirroring checker requires for
/// lib/core/codec/firestore_codec.dart — every concrete codec
/// (BookmarkCodec, GoalCodec, StageDefinitionCodec, ...) delegates its
/// timestamp/primitive coercions to this helper.
@Tags(['unit', 'sync'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';

void main() {
  group('FirestoreCodec.parseDateTime', () {
    test('returns null for a null input', () {
      expect(FirestoreCodec.parseDateTime(null), isNull);
    });

    test('shape 1/4 — DateTime passthrough is converted to UTC', () {
      final local = DateTime(2026, 6, 18, 10, 0, 0); // isUtc: false
      final result = FirestoreCodec.parseDateTime(local);

      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result, local.toUtc());
    });

    test('shape 1/4 — an already-UTC DateTime is returned unchanged', () {
      final utc = DateTime.utc(2026, 6, 18, 10, 0, 0);
      expect(FirestoreCodec.parseDateTime(utc), utc);
    });

    test('shape 2/4 — ISO-8601 String with Z suffix parses to UTC', () {
      final result = FirestoreCodec.parseDateTime('2026-06-18T10:00:00.000Z');

      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result, DateTime.utc(2026, 6, 18, 10, 0, 0));
    });

    test(
      'shape 2/4 — ISO-8601 String with explicit offset normalises to UTC',
      () {
        final result = FirestoreCodec.parseDateTime(
          '2026-06-18T12:00:00.000+02:00',
        );

        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
        expect(result, DateTime.utc(2026, 6, 18, 10, 0, 0));
      },
    );

    test('shape 2/4 — malformed String returns null', () {
      expect(FirestoreCodec.parseDateTime('not-a-date'), isNull);
    });

    test('shape 3/4 — int is interpreted as Unix epoch seconds (UTC)', () {
      // 2026-06-18T10:00:00Z
      const epochSeconds = 1781776800;
      final result = FirestoreCodec.parseDateTime(epochSeconds);

      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result, DateTime.utc(2026, 6, 18, 10, 0, 0));
    });

    test('shape 4/4 — Map with int "seconds" key (Timestamp JSON)', () {
      const epochSeconds = 1781776800;
      final result = FirestoreCodec.parseDateTime({'seconds': epochSeconds});

      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result, DateTime.utc(2026, 6, 18, 10, 0, 0));
    });

    test('shape 4/4 — Map missing "seconds" returns null', () {
      expect(FirestoreCodec.parseDateTime({'nanoseconds': 0}), isNull);
    });

    test('shape 4/4 — Map with non-int "seconds" returns null', () {
      expect(FirestoreCodec.parseDateTime({'seconds': 'not-an-int'}), isNull);
    });

    test('unrecognised shape (bool) returns null', () {
      expect(FirestoreCodec.parseDateTime(true), isNull);
    });
  });

  group('FirestoreCodec.encodeDateTime', () {
    test('returns null for a null input', () {
      expect(FirestoreCodec.encodeDateTime(null), isNull);
    });

    test('always produces a Z-suffixed UTC string, even from a local '
        '(non-UTC-flagged) DateTime', () {
      final local = DateTime(2026, 6, 18, 12, 0, 0); // isUtc: false
      final result = FirestoreCodec.encodeDateTime(local);

      expect(result, isNotNull);
      expect(result, endsWith('Z'));
      expect(DateTime.parse(result!).toUtc(), local.toUtc());
    });

    test('an already-UTC DateTime round-trips to the same instant', () {
      final utc = DateTime.utc(2026, 6, 18, 10, 0, 0);
      final result = FirestoreCodec.encodeDateTime(utc);

      expect(result, '2026-06-18T10:00:00.000Z');
    });

    test('round-trips through parseDateTime', () {
      final ts = DateTime.utc(2026, 3, 15, 12, 30);
      final encoded = FirestoreCodec.encodeDateTime(ts);
      expect(FirestoreCodec.parseDateTime(encoded), ts);
    });
  });

  group('FirestoreCodec.parseInt', () {
    test('returns null for a null input', () {
      expect(FirestoreCodec.parseInt(null), isNull);
    });

    test('int passthrough', () {
      expect(FirestoreCodec.parseInt(42), 42);
    });

    test('num (double) truncates toward zero via toInt()', () {
      expect(FirestoreCodec.parseInt(42.9), 42);
      expect(FirestoreCodec.parseInt(-42.9), -42);
    });

    test('numeric String parses to int', () {
      expect(FirestoreCodec.parseInt('42'), 42);
    });

    test('negative numeric String parses to int', () {
      expect(FirestoreCodec.parseInt('-7'), -7);
    });

    test('malformed String returns null', () {
      expect(FirestoreCodec.parseInt('not-a-number'), isNull);
    });

    test('unrecognised type (bool) returns null', () {
      expect(FirestoreCodec.parseInt(true), isNull);
    });
  });

  group('FirestoreCodec.parseBool', () {
    test('returns null for a null input', () {
      expect(FirestoreCodec.parseBool(null), isNull);
    });

    test('bool passthrough — true', () {
      expect(FirestoreCodec.parseBool(true), isTrue);
    });

    test('bool passthrough — false', () {
      expect(FirestoreCodec.parseBool(false), isFalse);
    });

    test('int 0 coerces to false', () {
      expect(FirestoreCodec.parseBool(0), isFalse);
    });

    test('non-zero int coerces to true', () {
      expect(FirestoreCodec.parseBool(1), isTrue);
      expect(FirestoreCodec.parseBool(-1), isTrue);
    });

    test('String "true" coerces to true', () {
      expect(FirestoreCodec.parseBool('true'), isTrue);
    });

    test('String "false" coerces to false', () {
      expect(FirestoreCodec.parseBool('false'), isFalse);
    });

    test('malformed String (not "true"/"false") returns null', () {
      expect(FirestoreCodec.parseBool('yes'), isNull);
    });

    test('unrecognised type (double) returns null', () {
      expect(FirestoreCodec.parseBool(1.5), isNull);
    });
  });
}
