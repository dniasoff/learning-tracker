/// Unit tests for [LearningOrderCodec]: encode<->decode round-trip and
/// required-field null-guards.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/learning_order_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/learning_order_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = LearningOrderCodec();
  final updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  group('LearningOrderCodec — kind', () {
    test('kind is "learning_order"', () {
      expect(codec.kind, EntityKind.learningOrder);
    });
  });

  group('LearningOrderCodec — encode → decode round-trip', () {
    test('round-trips required fields', () {
      final row = LearningOrderRow(
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot',
        userSortOrder: 3,
        updatedAt: updatedAt,
      );
      final decoded = codec.decode(codec.encode(row));
      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, 'bavli');
      expect(decoded.sefariaRef, 'Berakhot');
      expect(decoded.userSortOrder, 3);
      expect(decoded.updatedAt, updatedAt);
    });

    test('updated_at is omitted from encode() output when null', () {
      final payload = codec.encode(
        const LearningOrderRow(
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
        ),
      );
      expect(payload.containsKey('updated_at'), isFalse);
    });

    test(
      'is_custom_ordered and display_name_* are never emitted by encode()',
      () {
        final payload = codec.encode(
          const LearningOrderRow(
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
            isCustomOrdered: true,
            displayNameHe: 'ברכות',
            displayNameEn: 'Berakhot',
          ),
        );
        expect(payload.containsKey('is_custom_ordered'), isFalse);
        expect(payload.containsKey('display_name_he'), isFalse);
        expect(payload.containsKey('display_name_en'), isFalse);
      },
    );
  });

  group('LearningOrderCodec — userSortOrder=0 is preserved (not dropped)', () {
    test('sortOrder 0 round-trips correctly', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot',
        'user_sort_order': 0,
      });
      expect(decoded?.userSortOrder, 0);
    });
  });

  group('LearningOrderCodec — decode returns null for malformed inputs', () {
    test('missing curriculum_id', () {
      expect(
        codec.decode({'sefaria_ref': 'Berakhot', 'user_sort_order': 0}),
        isNull,
      );
    });

    test('missing sefaria_ref', () {
      expect(
        codec.decode({'curriculum_id': 'bavli', 'user_sort_order': 0}),
        isNull,
      );
    });

    test('missing user_sort_order', () {
      expect(
        codec.decode({'curriculum_id': 'bavli', 'sefaria_ref': 'Berakhot'}),
        isNull,
      );
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('LearningOrderCodec — is_custom_ordered decode default', () {
    test('missing is_custom_ordered defaults to false', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot',
        'user_sort_order': 0,
      });
      expect(decoded?.isCustomOrdered, isFalse);
    });
  });
}
