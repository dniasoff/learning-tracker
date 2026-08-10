/// Unit tests for [LearningLedgerCodec]: encode<->decode round-trip,
/// required-field null-guards, and the snake_case/camelCase dual-read
/// fallback (C1 regression surface).
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/learning_ledger_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/learning_ledger_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = LearningLedgerCodec();
  final completedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  LearningLedgerRow row({int? trackId}) => LearningLedgerRow(
    ulid: 'ULID1',
    profileId: 1,
    curriculumId: 'bavli',
    entryScope: 'masechta',
    unitIdentifier: 'Berakhot',
    unitDisplayNameHe: 'ברכות',
    unitDisplayNameEn: 'Berakhot',
    trackType: 'personal',
    trackId: trackId,
    completedAt: completedAt,
    completionNumber: 1,
    markedBy: 1,
    isManual: false,
  );

  group('LearningLedgerCodec — kind', () {
    test('kind is "learning_ledger"', () {
      expect(codec.kind, EntityKind.learningLedger);
    });
  });

  group('LearningLedgerCodec — encode → decode round-trip', () {
    test('round-trips all fields', () {
      final decoded = codec.decode(codec.encode(row()));
      expect(decoded, isNotNull);
      expect(decoded!.ulid, 'ULID1');
      expect(decoded.curriculumId, 'bavli');
      expect(decoded.unitIdentifier, 'Berakhot');
      expect(decoded.unitDisplayNameHe, 'ברכות');
      expect(decoded.trackType, 'personal');
      expect(decoded.completedAt, completedAt);
      expect(decoded.completionNumber, 1);
      expect(decoded.markedBy, 1);
      expect(decoded.isManual, isFalse);
    });

    test('null trackId round-trips as null', () {
      expect(codec.decode(codec.encode(row()))?.trackId, isNull);
    });

    test('non-null trackId round-trips', () {
      expect(codec.decode(codec.encode(row(trackId: 5)))?.trackId, 5);
    });

    test('completed_at survives encode() when completedAt is non-UTC-flagged '
        '(AUD-core-sync-11: simulates the Drift round-trip, where '
        'dateTime() columns decode via DateTime.fromMillisecondsSinceEpoch '
        'with no isUtc:true, producing a local-flagged DateTime that still '
        'represents the correct instant)', () {
      // The real UTC instant the entry was completed at.
      final utcInstant = DateTime.utc(2026, 6, 18, 10, 0, 0);

      // Simulate what Drift's dateTime() column getter hands back: the
      // same instant, but flagged as local (isUtc: false) rather than
      // UTC — exactly what
      // DateTime.fromMillisecondsSinceEpoch(ms) (no isUtc:true) produces.
      final driftDecodedCompletedAt = DateTime.fromMillisecondsSinceEpoch(
        utcInstant.millisecondsSinceEpoch,
      );
      expect(
        driftDecodedCompletedAt.isUtc,
        isFalse,
        reason:
            'test setup must simulate the non-UTC-flagged value Drift '
            'actually returns; if this ever becomes true the simulation '
            'no longer matches the bug this test guards against.',
      );

      final withDriftCompletedAt = LearningLedgerRow(
        ulid: 'ULID1',
        profileId: 1,
        curriculumId: 'bavli',
        entryScope: 'masechta',
        unitIdentifier: 'Berakhot',
        unitDisplayNameHe: 'ברכות',
        unitDisplayNameEn: 'Berakhot',
        trackType: 'personal',
        completedAt: driftDecodedCompletedAt,
        completionNumber: 1,
        markedBy: 1,
        isManual: false,
      );

      final encoded = codec.encode(withDriftCompletedAt);
      final wireValue = encoded['completed_at'] as String;

      expect(
        wireValue,
        endsWith('Z'),
        reason:
            'completed_at must always be pushed via '
            'FirestoreCodec.encodeDateTime (which forces .toUtc() before '
            'serializing) like every sibling DateTime field in this '
            'codec and every other codec in the batch. A raw '
            '.toIso8601String() on a non-UTC-flagged DateTime omits the '
            "'Z'/offset entirely, so a reading device on a different "
            'timezone reinterprets the naive string using its OWN local '
            'offset — silently shifting completedAt onto the wrong '
            'calendar day.',
      );

      // The wire value must decode back to the exact same instant,
      // independent of whichever local offset this test machine runs
      // under.
      expect(DateTime.parse(wireValue).toUtc(), utcInstant);

      // decode(encode(x)) round-trips to the correct UTC instant too —
      // this is the timezone-independence guarantee for the full codec
      // pipeline, not just the raw wire string.
      final decoded = codec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.completedAt.toUtc(), utcInstant);
    });
  });

  group('LearningLedgerCodec — snake_case/camelCase dual read (C1)', () {
    test('snake_case keys decode', () {
      final decoded = codec.decode({
        'ulid': 'U1',
        'profile_id': 1,
        'curriculum_id': 'bavli',
        'entry_scope': 'masechta',
        'unit_identifier': 'Berakhot',
        'track_type': 'personal',
        'completed_at': completedAt.toIso8601String(),
      });
      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, 'bavli');
    });

    test('legacy camelCase keys decode (fallback) — curriculum_id has no '
        'camelCase fallback in the codec, so it stays snake_case here', () {
      final decoded = codec.decode({
        'ulid': 'U1',
        'profile_id': 1,
        'curriculum_id': 'mishnayos',
        'entryScope': 'masechta',
        'unitIdentifier': 'Avot',
        'trackType': 'personal',
        'completedAt': completedAt.toIso8601String(),
      });
      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, 'mishnayos');
      expect(decoded.unitIdentifier, 'Avot');
    });
  });

  group('LearningLedgerCodec — decode returns null for malformed inputs', () {
    test('missing ulid', () {
      expect(
        codec.decode({
          'profile_id': 1,
          'curriculum_id': 'bavli',
          'entry_scope': 'masechta',
          'unit_identifier': 'Berakhot',
          'track_type': 'personal',
          'completed_at': completedAt.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing curriculum_id (both spellings absent)', () {
      expect(
        codec.decode({
          'ulid': 'U1',
          'profile_id': 1,
          'entry_scope': 'masechta',
          'unit_identifier': 'Berakhot',
          'track_type': 'personal',
          'completed_at': completedAt.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing completed_at', () {
      expect(
        codec.decode({
          'ulid': 'U1',
          'profile_id': 1,
          'curriculum_id': 'bavli',
          'entry_scope': 'masechta',
          'unit_identifier': 'Berakhot',
          'track_type': 'personal',
        }),
        isNull,
      );
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('LearningLedgerCodec — defaults', () {
    final minimal = {
      'ulid': 'U1',
      'profile_id': 1,
      'curriculum_id': 'bavli',
      'entry_scope': 'masechta',
      'unit_identifier': 'Berakhot',
      'track_type': 'personal',
      'completed_at': completedAt.toIso8601String(),
    };

    test('unit_display_name_he/en default to empty string', () {
      final decoded = codec.decode(minimal);
      expect(decoded?.unitDisplayNameHe, '');
      expect(decoded?.unitDisplayNameEn, '');
    });

    test('completion_number defaults to 1', () {
      expect(codec.decode(minimal)?.completionNumber, 1);
    });

    test('marked_by defaults to 0', () {
      expect(codec.decode(minimal)?.markedBy, 0);
    });

    test('is_manual defaults to false', () {
      expect(codec.decode(minimal)?.isManual, isFalse);
    });
  });
}
