// Tests for BookmarkEntity — covers copyWith, and fromFirestore's tolerant
// updated_at decode (every wire shape FirestoreCodec.parseDateTime plus a
// real Timestamp support) and its malformed-document error paths.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';

void main() {
  final base = BookmarkEntity(
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: 'Berakhot 1:1',
    updatedAt: DateTime.utc(2026, 3, 15),
  );

  // =========================================================================
  // BookmarkEntity.copyWith
  // =========================================================================

  group('BookmarkEntity.copyWith', () {
    test('returns an equivalent copy when called with no overrides', () {
      final copy = base.copyWith();
      expect(copy.curriculumId, base.curriculumId);
      expect(copy.sefariaRef, base.sefariaRef);
      expect(copy.updatedAt, base.updatedAt);
    });

    test('overrides sefariaRef only', () {
      final copy = base.copyWith(sefariaRef: 'Berakhot 5:1');
      expect(copy.sefariaRef, 'Berakhot 5:1');
      expect(copy.curriculumId, base.curriculumId);
      expect(copy.updatedAt, base.updatedAt);
    });

    test('overrides updatedAt only', () {
      final newTs = DateTime.utc(2026, 4, 1);
      final copy = base.copyWith(updatedAt: newTs);
      expect(copy.updatedAt, newTs);
      expect(copy.sefariaRef, base.sefariaRef);
    });

    test('overrides both sefariaRef and updatedAt', () {
      final newTs = DateTime.utc(2026, 5, 10);
      final copy = base.copyWith(sefariaRef: 'Berakhot 10:1', updatedAt: newTs);
      expect(copy.sefariaRef, 'Berakhot 10:1');
      expect(copy.updatedAt, newTs);
    });
  });

  // =========================================================================
  // BookmarkEntity.fromFirestore — error path
  // =========================================================================

  group('BookmarkEntity.fromFirestore', () {
    test('throws ArgumentError for unknown curriculumId', () {
      expect(
        () => BookmarkEntity.fromFirestore({
          'curriculum_id': 'unknown_curriculum_xyz',
          'track_type': 'personal',
          'content_item_id': 'Ref',
          'updated_at': '2026-03-15T00:00:00.000Z',
        }),
        throwsArgumentError,
      );
    });

    test('parses a valid firestore map', () {
      final entity = BookmarkEntity.fromFirestore({
        'curriculum_id': 'mishnayos',
        'track_type': 'personal',
        'content_item_id': 'Berakhot 1:1',
        'updated_at': '2026-03-15T00:00:00.000Z',
      });
      expect(entity.curriculumId, CurriculumId.mishnayos);
      expect(entity.sefariaRef, 'Berakhot 1:1');
    });

    test('throws ArgumentError when curriculum_id is missing (not just '
        'unknown)', () {
      // Before the fix, `data['curriculum_id'] as String` on a null value
      // threw a bare TypeError rather than the same ArgumentError the
      // "unknown curriculumId" case raises — missing and unknown should
      // fail the same documented way.
      expect(
        () => BookmarkEntity.fromFirestore({
          'content_item_id': 'Berakhot 1:1',
          'updated_at': '2026-03-15T00:00:00.000Z',
        }),
        throwsArgumentError,
      );
    });

    // =======================================================================
    // updated_at — every wire shape FirestoreCodec.parseDateTime supports,
    // plus a real Firestore Timestamp. Every case must decode to a UTC
    // DateTime representing the exact same instant, matched with `==` (which
    // in Dart also compares the isUtc flag — so a decode that forgets the
    // final `.toUtc()` fails this even when the numeric instant is right).
    // =======================================================================

    final expected = DateTime.utc(2026, 3, 15, 12, 0, 0);

    Map<String, dynamic> docWith(Object updatedAt) => {
      'curriculum_id': 'mishnayos',
      'content_item_id': 'Berakhot 1:1',
      'updated_at': updatedAt,
    };

    test('decodes updated_at from an ISO-8601 string, in UTC', () {
      final entity = BookmarkEntity.fromFirestore(
        docWith(expected.toIso8601String()),
      );
      expect(entity.updatedAt, expected);
      expect(entity.updatedAt.isUtc, isTrue);
    });

    test('decodes updated_at from epoch-seconds int, in UTC', () {
      final epochSeconds = expected.millisecondsSinceEpoch ~/ 1000;
      final entity = BookmarkEntity.fromFirestore(docWith(epochSeconds));
      expect(entity.updatedAt, expected);
      expect(entity.updatedAt.isUtc, isTrue);
    });

    test('decodes updated_at from a {seconds: ...} map (Timestamp JSON), '
        'in UTC', () {
      final epochSeconds = expected.millisecondsSinceEpoch ~/ 1000;
      final entity = BookmarkEntity.fromFirestore(
        docWith({'seconds': epochSeconds}),
      );
      expect(entity.updatedAt, expected);
      expect(entity.updatedAt.isUtc, isTrue);
    });

    test('decodes updated_at from a real Firestore Timestamp, converting '
        'local-flagged toDate() output to UTC', () {
      // This is what `snapshot.data()['updated_at']` actually is on every
      // read of a document written with FieldValue.serverTimestamp() (the
      // gateway's pushBookmark, and the tutor-proxy Cloud Function) — a
      // real Timestamp, not a String. Timestamp.toDate() itself returns a
      // DateTime flagged local (see cloud_firestore_platform_interface's
      // Timestamp.toDate()); fromFirestore must correct that to UTC.
      final entity = BookmarkEntity.fromFirestore(
        docWith(Timestamp.fromDate(expected)),
      );
      expect(entity.updatedAt, expected);
      expect(entity.updatedAt.isUtc, isTrue);
    });

    // =======================================================================
    // Malformed documents — updated_at missing/unparseable throws rather
    // than silently fabricating "now" (which would let a corrupt document
    // masquerade as the freshest bookmark in a cross-device LWW merge
    // elsewhere). Safe to throw here: resilientDocStream forwards a decode
    // failure via addError without resubscribing, so it does not leave
    // watchBookmark's stream permanently dead.
    // =======================================================================

    test('throws ArgumentError when updated_at is missing', () {
      expect(
        () => BookmarkEntity.fromFirestore({
          'curriculum_id': 'mishnayos',
          'content_item_id': 'Berakhot 1:1',
        }),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when updated_at is null', () {
      expect(
        () => BookmarkEntity.fromFirestore({
          'curriculum_id': 'mishnayos',
          'content_item_id': 'Berakhot 1:1',
          'updated_at': null,
        }),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when updated_at is an unparseable string', () {
      expect(
        () => BookmarkEntity.fromFirestore(docWith('not-a-date')),
        throwsArgumentError,
      );
    });
  });
}
