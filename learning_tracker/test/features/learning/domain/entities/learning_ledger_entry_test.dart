/// Unit tests for
/// `lib/features/learning/domain/entities/learning_ledger_entry.dart` — the
/// pure-Dart `LearningLedgerEntry` model and its
/// `LearningLedgerEntryFirestoreCodec.toFirestore`/
/// `learningLedgerEntryFromFirestore` codec functions. No
/// `fake_cloud_firestore` here: these are plain map round-trips, mirroring
/// `bookmark_entity_test.dart`'s style. Repository-level behavior (doc-id,
/// retry-idempotency, decode leniency in a live collection) is already
/// covered by
/// `test/data/repositories/firestore_learning_ledger_repository_test.dart`.
///
/// **`completed_at` matters most here.** `firestore.rules`' `learning_ledger`
/// SR-3 create guard requires `completed_at is timestamp`
/// (`match /learning_ledger/{entryId}`), and a plain Dart `String` is type
/// `string` in Firestore's eyes, not `timestamp` — the model's own class doc
/// comment calls this out as "the one deliberate divergence" from the
/// `FirestoreCodec.encodeDateTime`-String pattern used elsewhere in this
/// codebase. `toFirestore` writes `completedAt.toUtc()` directly (a raw
/// `DateTime`), NOT `FirestoreCodec.encodeDateTime(completedAt)`. Verified
/// below — this is the one field this suite would fail loudly on if a future
/// edit "fixed" it back to the String form.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';

void main() {
  final base = LearningLedgerEntry(
    ulid: 'ULID00000000000000000001',
    curriculumId: CurriculumId.mishnayos,
    entryScope: 'masechta',
    unitIdentifier: 'Berachos',
    unitDisplayNameHe: 'ברכות',
    unitDisplayNameEn: 'Berachos',
    completedAt: DateTime.utc(2026, 3, 1, 12),
    completionNumber: 2,
    markedBy: 'profile-ulid-1',
    isManual: true,
    trackType: 'personal',
    source: CompletionSource.live,
  );

  group('round-trip', () {
    test('every field survives toFirestore -> fromFirestore', () {
      final decoded = learningLedgerEntryFromFirestore(base.toFirestore());

      expect(decoded.ulid, base.ulid);
      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.entryScope, base.entryScope);
      expect(decoded.unitIdentifier, base.unitIdentifier);
      expect(decoded.unitDisplayNameHe, base.unitDisplayNameHe);
      expect(decoded.unitDisplayNameEn, base.unitDisplayNameEn);
      expect(decoded.trackType, base.trackType);
      expect(decoded.completedAt, base.completedAt);
      expect(decoded.completionNumber, base.completionNumber);
      expect(decoded.markedBy, base.markedBy);
      expect(decoded.isManual, base.isManual);
      expect(decoded.source, base.source);
    });

    test('a non-manual entry round-trips isManual: false', () {
      final manual = LearningLedgerEntry(
        ulid: 'ULID00000000000000000002',
        curriculumId: CurriculumId.bavli,
        entryScope: 'sefer',
        unitIdentifier: 'Bava Kama',
        unitDisplayNameHe: 'בבא קמא',
        unitDisplayNameEn: 'Bava Kama',
        completedAt: DateTime.utc(2026, 3, 2),
        completionNumber: 1,
        markedBy: 'profile-ulid-2',
        isManual: false,
        trackType: 'personal',
        source: CompletionSource.bulkInTrack,
      );

      final decoded = learningLedgerEntryFromFirestore(manual.toFirestore());
      expect(decoded.isManual, isFalse);
      expect(decoded.source, CompletionSource.bulkInTrack);
    });

    test('every CompletionSource round-trips via .name', () {
      for (final source in CompletionSource.values) {
        final entry = LearningLedgerEntry(
          ulid: 'ULID0000000000000000SRC${source.index}',
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'unit-${source.name}',
          unitDisplayNameHe: 'שם',
          unitDisplayNameEn: 'Name',
          completedAt: DateTime.utc(2026, 3, 1),
          completionNumber: 1,
          markedBy: 'profile-ulid-1',
          isManual: false,
          trackType: 'personal',
          source: source,
        );

        final payload = entry.toFirestore();
        expect(
          payload['source'],
          source.name,
          reason: 'written as CompletionSource.name, not a hand-rolled key',
        );
        expect(learningLedgerEntryFromFirestore(payload).source, source);
      }
    });
  });

  group('field names match the firestore.rules `learning_ledger` shape', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      final payload = base.toFirestore();

      expect(payload.keys.toSet(), <String>{
        'ulid',
        'curriculum_id',
        'entry_scope',
        'unit_identifier',
        'unit_display_name_he',
        'unit_display_name_en',
        'track_type',
        'completed_at',
        'completion_number',
        'marked_by',
        'is_manual',
        'source',
        'purged_at',
      });
    });

    test('curriculum_id is written as the CurriculumId storageKey string', () {
      expect(base.toFirestore()['curriculum_id'], 'mishnayos');
    });
  });

  group('completed_at is a raw DateTime, NOT an ISO-8601 String — SR-3 '
      '`is timestamp` guard', () {
    test('toFirestore writes completed_at as a DateTime', () {
      final payload = base.toFirestore();
      expect(
        payload['completed_at'],
        isA<DateTime>(),
        reason:
            'firestore.rules requires completed_at is timestamp on '
            'create; a String value is type string in Firestore\'s eyes '
            'and would fail every recordCompletion call in production',
      );
    });

    test('the DateTime is normalised to UTC', () {
      final local = LearningLedgerEntry(
        ulid: 'ULID00000000000000000003',
        curriculumId: CurriculumId.chumash,
        entryScope: 'sefer',
        unitIdentifier: 'Bereishis',
        unitDisplayNameHe: 'בראשית',
        unitDisplayNameEn: 'Bereishis',
        completedAt: DateTime.utc(2026, 3, 3, 8),
        completionNumber: 1,
        markedBy: 'profile-ulid-3',
        isManual: false,
        trackType: 'personal',
        source: CompletionSource.lifetimeOnly,
      );

      final payload = local.toFirestore();
      expect((payload['completed_at'] as DateTime).isUtc, isTrue);
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test('toFirestore never writes track_id or a Drift-style id', () {
      final payload = base.toFirestore();
      expect(payload, isNot(contains('track_id')));
      expect(payload, isNot(contains('id')));
    });
  });

  group('learningLedgerEntryFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'ulid': 'ULID00000000000000000004',
      'curriculum_id': 'mishnayos',
      'entry_scope': 'masechta',
      'unit_identifier': 'Berachos',
      'unit_display_name_he': 'ברכות',
      'unit_display_name_en': 'Berachos',
      'track_type': 'personal',
      'completed_at': DateTime.utc(2026, 3, 1),
      'completion_number': 2,
      'marked_by': 'profile-ulid-1',
      'is_manual': true,
    };

    test('throws ArgumentError for an unrecognised curriculum_id', () {
      final data = validMap()..['curriculum_id'] = 'not-a-real-curriculum';
      expect(
        () => learningLedgerEntryFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when curriculum_id is missing entirely', () {
      final data = validMap()..remove('curriculum_id');
      expect(
        () => learningLedgerEntryFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when ulid is missing', () {
      final data = validMap()..remove('ulid');
      expect(
        () => learningLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when completed_at is missing', () {
      final data = validMap()..remove('completed_at');
      expect(
        () => learningLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when marked_by is missing', () {
      final data = validMap()..remove('marked_by');
      expect(
        () => learningLedgerEntryFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'completion_number defaults to 1 when missing — documented fallback',
      () {
        final data = validMap()..remove('completion_number');
        final decoded = learningLedgerEntryFromFirestore(data);
        expect(decoded.completionNumber, 1);
      },
    );

    test('is_manual defaults to false when missing — documented fallback', () {
      final data = validMap()..remove('is_manual');
      final decoded = learningLedgerEntryFromFirestore(data);
      expect(decoded.isManual, isFalse);
    });

    test('entryScope/unitIdentifier/display names/trackType default to '
        'empty string when missing — documented fallback', () {
      final data = validMap()
        ..remove('entry_scope')
        ..remove('unit_identifier')
        ..remove('unit_display_name_he')
        ..remove('unit_display_name_en')
        ..remove('track_type');
      final decoded = learningLedgerEntryFromFirestore(data);

      expect(decoded.entryScope, '');
      expect(decoded.unitIdentifier, '');
      expect(decoded.unitDisplayNameHe, '');
      expect(decoded.unitDisplayNameEn, '');
      expect(decoded.trackType, '');
    });

    test('completed_at as a real Firestore Timestamp read-back (already a '
        'DateTime by the time it reaches this function) decodes correctly', () {
      final decoded = learningLedgerEntryFromFirestore(validMap());
      expect(decoded.completedAt, DateTime.utc(2026, 3, 1));
    });

    test('source defaults to CompletionSource.live when missing — an honest '
        'default for an unmarked-provenance legacy document, not a retraction '
        'fail-safe (retraction keys on coverage, not source — see '
        'LearningLedgerEntry\'s class doc comment)', () {
      final data = validMap()..remove('source');
      final decoded = learningLedgerEntryFromFirestore(data);
      expect(decoded.source, CompletionSource.live);
    });

    test('an unrecognised source value decodes as CompletionSource.live rather '
        'than throwing', () {
      final data = validMap()..['source'] = 'not-a-real-source';
      final decoded = learningLedgerEntryFromFirestore(data);
      expect(decoded.source, CompletionSource.live);
    });
  });
}
