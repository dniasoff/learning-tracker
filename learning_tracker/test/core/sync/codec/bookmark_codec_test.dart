/// Unit tests for [BookmarkCodec]: encode<->decode round-trip and the
/// dual-key (`sefaria_ref` vs legacy `content_item_id`) decode fallback.
///
/// AG-5 (AUD-app-05): new file — the codec's decode()/encode() shape was
/// previously exercised only indirectly through
/// test/sync/merge/bookmark_merger_test.dart's round-trip and legacy-key
/// groups (kept there since they test merge behaviour end-to-end); this
/// file adds the codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = BookmarkCodec();
  final updatedAt = DateTime.utc(2026, 6, 18, 14, 0, 0);

  group('BookmarkCodec — kind', () {
    test('kind is "bookmark"', () {
      expect(codec.kind, EntityKind.bookmark);
    });
  });

  group('BookmarkCodec — encode → decode round-trip', () {
    test('round-trips curriculumId, sefariaRef, updatedAt', () {
      final row = BookmarkRow(
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot 2a',
        updatedAt: updatedAt,
      );
      final decoded = codec.decode(codec.encode(row));

      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, 'bavli');
      expect(decoded.sefariaRef, 'Berakhot 2a');
      expect(decoded.updatedAt, updatedAt);
    });

    test('encode() emits sefaria_ref, never content_item_id', () {
      final payload = codec.encode(
        BookmarkRow(
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          updatedAt: updatedAt,
        ),
      );
      expect(payload['sefaria_ref'], 'Berakhot 2a');
      expect(payload.containsKey('content_item_id'), isFalse);
    });
  });

  group('BookmarkCodec — decode dual-key fallback', () {
    test('accepts the canonical sefaria_ref key', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot 2a',
        'updated_at': updatedAt.toIso8601String(),
      });
      expect(decoded?.sefariaRef, 'Berakhot 2a');
    });

    test('falls back to the legacy content_item_id key', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'content_item_id': 'Berakhot 3a',
        'updated_at': updatedAt.toIso8601String(),
      });
      expect(
        decoded?.sefariaRef,
        'Berakhot 3a',
        reason:
            'legacy pre-Phase-B documents wrote the ref under '
            'content_item_id — decode must still accept them',
      );
    });

    test('prefers sefaria_ref when both keys are present', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'canonical',
        'content_item_id': 'legacy',
        'updated_at': updatedAt.toIso8601String(),
      });
      expect(decoded?.sefariaRef, 'canonical');
    });
  });

  group('BookmarkCodec — decode returns null for malformed inputs', () {
    test('missing curriculum_id', () {
      expect(
        codec.decode({
          'sefaria_ref': 'Berakhot 2a',
          'updated_at': updatedAt.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing both sefaria_ref and content_item_id', () {
      expect(
        codec.decode({
          'curriculum_id': 'bavli',
          'updated_at': updatedAt.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing updated_at', () {
      expect(
        codec.decode({'curriculum_id': 'bavli', 'sefaria_ref': 'Berakhot 2a'}),
        isNull,
      );
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('BookmarkCodec — syncedAt', () {
    test('syncedAt is parsed on decode but never emitted by encode', () {
      final syncedAt = DateTime.utc(2026, 6, 18, 14, 0, 5);
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot 2a',
        'updated_at': updatedAt.toIso8601String(),
        'synced_at': syncedAt.toIso8601String(),
      });
      expect(decoded?.syncedAt, syncedAt);

      final payload = codec.encode(
        BookmarkRow(
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          updatedAt: updatedAt,
          syncedAt: syncedAt,
        ),
      );
      expect(
        payload.containsKey('synced_at'),
        isFalse,
        reason: 'synced_at is server-set (FieldValue.serverTimestamp())',
      );
    });
  });
}
