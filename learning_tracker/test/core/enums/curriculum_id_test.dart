import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

// AUD-core-labels-02: CurriculumId.fromStorageKey() is the single
// canonical storageKey→enum lookup. Every CurriculumId.values entry must
// round-trip through it, and unknown/empty keys must resolve to null
// rather than throwing or silently defaulting.
void main() {
  group('CurriculumId.fromStorageKey', () {
    for (final id in CurriculumId.values) {
      test('resolves ${id.storageKey} back to CurriculumId.$id', () {
        expect(CurriculumId.fromStorageKey(id.storageKey), id);
      });
    }

    test('returns null for an unrecognised key', () {
      expect(CurriculumId.fromStorageKey('not_a_real_curriculum'), isNull);
    });

    test('returns null for an empty key', () {
      expect(CurriculumId.fromStorageKey(''), isNull);
    });

    test('is case-sensitive (no accidental normalisation)', () {
      expect(CurriculumId.fromStorageKey('Mishnayos'), isNull);
      expect(CurriculumId.fromStorageKey('mishnayos'), CurriculumId.mishnayos);
    });
  });
}
