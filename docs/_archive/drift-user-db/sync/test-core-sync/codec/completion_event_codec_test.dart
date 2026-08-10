/// Unit tests for [CompletionEventCodec]: encode<->decode round-trip,
/// required-field null-guards, and the conditional prior_mark_only /
/// track_id keys.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/completion_event_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/completion_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = CompletionEventCodec();
  final eventTimestamp = DateTime.utc(2026, 6, 18, 12, 0, 0);

  CompletionEventRow row({
    int profileId = 1,
    String curriculumId = 'bavli',
    String sefariaRef = 'Berakhot 2a',
    int stageId = 1,
    String trackType = 'standard',
    int? trackId,
    int points = 10,
    bool priorMarkOnly = false,
  }) => CompletionEventRow(
    profileId: profileId,
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: trackType,
    trackId: trackId,
    eventTimestamp: eventTimestamp,
    points: points,
    priorMarkOnly: priorMarkOnly,
  );

  group('CompletionEventCodec — kind', () {
    test('kind is "completion"', () {
      expect(codec.kind, EntityKind.completion);
    });
  });

  group('CompletionEventCodec — encode → decode round-trip', () {
    test('round-trips required fields', () {
      final decoded = codec.decode(codec.encode(row()));
      expect(decoded, isNotNull);
      expect(decoded!.profileId, 1);
      expect(decoded.curriculumId, 'bavli');
      expect(decoded.sefariaRef, 'Berakhot 2a');
      expect(decoded.stageId, 1);
      expect(decoded.trackType, 'standard');
      expect(decoded.points, 10);
      expect(decoded.eventTimestamp, eventTimestamp);
    });

    test('track_id is emitted only when non-null', () {
      expect(codec.encode(row()).containsKey('track_id'), isFalse);
      expect(codec.encode(row(trackId: 42))['track_id'], 42);
    });

    test('prior_mark_only is emitted only when true', () {
      expect(
        codec.encode(row(priorMarkOnly: false)).containsKey('prior_mark_only'),
        isFalse,
      );
      expect(codec.encode(row(priorMarkOnly: true))['prior_mark_only'], true);
    });
  });

  group(
    'CompletionEventCodec — decode accepts completed_at or event_timestamp',
    () {
      test('completed_at key is read', () {
        final decoded = codec.decode({
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot 2a',
          'stage_id': 1,
          'track_type': 'standard',
          'completed_at': eventTimestamp.toIso8601String(),
        });
        expect(decoded?.eventTimestamp, eventTimestamp);
      });

      test('legacy event_timestamp key is a fallback', () {
        final decoded = codec.decode({
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot 2a',
          'stage_id': 1,
          'track_type': 'standard',
          'event_timestamp': eventTimestamp.toIso8601String(),
        });
        expect(decoded?.eventTimestamp, eventTimestamp);
      });
    },
  );

  group('CompletionEventCodec — decode returns null for malformed inputs', () {
    test('missing curriculum_id', () {
      expect(
        codec.decode({
          'sefaria_ref': 'Berakhot 2a',
          'stage_id': 1,
          'track_type': 'standard',
          'completed_at': eventTimestamp.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing sefaria_ref', () {
      expect(
        codec.decode({
          'curriculum_id': 'bavli',
          'stage_id': 1,
          'track_type': 'standard',
          'completed_at': eventTimestamp.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing stage_id', () {
      expect(
        codec.decode({
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot 2a',
          'track_type': 'standard',
          'completed_at': eventTimestamp.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing track_type', () {
      expect(
        codec.decode({
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot 2a',
          'stage_id': 1,
          'completed_at': eventTimestamp.toIso8601String(),
        }),
        isNull,
      );
    });

    test('missing both completed_at and event_timestamp', () {
      expect(
        codec.decode({
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot 2a',
          'stage_id': 1,
          'track_type': 'standard',
        }),
        isNull,
      );
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('CompletionEventCodec — defaults', () {
    test('missing points defaults to 0', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot 2a',
        'stage_id': 1,
        'track_type': 'standard',
        'completed_at': eventTimestamp.toIso8601String(),
      });
      expect(decoded?.points, 0);
    });

    test('missing prior_mark_only defaults to false', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot 2a',
        'stage_id': 1,
        'track_type': 'standard',
        'completed_at': eventTimestamp.toIso8601String(),
      });
      expect(decoded?.priorMarkOnly, isFalse);
    });

    test('missing profile_id defaults to 0', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot 2a',
        'stage_id': 1,
        'track_type': 'standard',
        'completed_at': eventTimestamp.toIso8601String(),
      });
      expect(decoded?.profileId, 0);
    });
  });
}
