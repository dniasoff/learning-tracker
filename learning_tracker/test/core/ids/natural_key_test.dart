/// Unit tests for [NaturalKey] factory constructors.
///
/// AUD-core-ids-01: locks in the exact key-format strings the mergers used
/// to hand-build inline (`'${curriculumId}|${trackId}|${stageOrder}'` etc.)
/// before this fix routed them through the matching `NaturalKey.forX`
/// factory. A future change to a factory's separator or field order must
/// break loudly here — in the one place that owns the shape — instead of
/// silently diverging from what `DriftMergeStore`/`SyncKv` has already
/// persisted for existing rows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/ids/natural_key.dart';

void main() {
  group('NaturalKey.forStageDefinition', () {
    test('produces the exact curriculumId|trackId|stageOrder shape', () {
      final key = NaturalKey.forStageDefinition(
        curriculumId: 'bavli',
        trackId: 7,
        stageOrder: 0,
      );

      // Must match StageDefinitionMerger's pre-fix hand-built string
      // exactly — this is the format already persisted in SyncKv.
      expect(key.value, 'bavli|7|0');
    });

    test('interpolates non-int Object trackId/stageOrder via toString', () {
      final key = NaturalKey.forStageDefinition(
        curriculumId: 'yerushalmi',
        trackId: '3',
        stageOrder: '2',
      );

      expect(key.value, 'yerushalmi|3|2');
    });
  });

  group('NaturalKey.forLearningOrder', () {
    test('produces the exact curriculumId|sefariaRef shape', () {
      final key = NaturalKey.forLearningOrder(
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot',
      );

      // Must match LearningOrderMerger's pre-fix hand-built string exactly.
      expect(key.value, 'bavli|Berakhot');
    });
  });

  group('NaturalKey.forSettings', () {
    test('equals the raw curriculumId (single-column shape)', () {
      expect(NaturalKey.forSettings(curriculumId: 'bavli').value, 'bavli');
    });
  });

  group('NaturalKey.forBookmark', () {
    test('equals the raw curriculumId (single-column shape)', () {
      expect(NaturalKey.forBookmark(curriculumId: 'bavli').value, 'bavli');
    });
  });

  group('NaturalKey.forTrackConfig', () {
    test('equals the raw curriculumId (single-column shape)', () {
      expect(NaturalKey.forTrackConfig(curriculumId: 'bavli').value, 'bavli');
    });
  });

  group('NaturalKey.fromSingle', () {
    test('wraps the given string unchanged', () {
      expect(NaturalKey.fromSingle('bavli').value, 'bavli');
    });
  });

  group('NaturalKey.forCompletion', () {
    test('prefers a non-empty firestoreId over the composite fallback', () {
      final key = NaturalKey.forCompletion(
        firestoreId: 'doc-123',
        profileId: 1,
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot 2a',
        completedAt: '2026-07-01T00:00:00.000Z',
      );

      expect(key.value, 'doc-123');
    });

    test('falls back to the 4-column composite when firestoreId is null', () {
      final key = NaturalKey.forCompletion(
        firestoreId: null,
        profileId: 1,
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot 2a',
        completedAt: '2026-07-01T00:00:00.000Z',
      );

      expect(key.value, '1|bavli|Berakhot 2a|2026-07-01T00:00:00.000Z');
    });

    test('falls back to the composite when firestoreId is empty', () {
      final key = NaturalKey.forCompletion(
        firestoreId: '',
        profileId: 1,
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot 2a',
        completedAt: '2026-07-01T00:00:00.000Z',
      );

      expect(key.value, '1|bavli|Berakhot 2a|2026-07-01T00:00:00.000Z');
    });
  });
}
