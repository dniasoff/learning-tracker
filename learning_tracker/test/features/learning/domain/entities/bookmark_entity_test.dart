// Tests for BookmarkEntity — covers copyWith (lines 22-28) and
// fromFirestore error path (lines 50-51).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';

void main() {
  final base = BookmarkEntity(
    curriculumId: CurriculumId.mishnayos,
    trackType: TrackType.personal,
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
      expect(copy.trackType, base.trackType);
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
  });
}
