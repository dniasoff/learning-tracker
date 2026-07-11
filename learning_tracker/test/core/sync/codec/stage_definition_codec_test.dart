/// Unit tests for [StageDefinitionCodec] encode<->decode round-trips (all
/// schedule branches, legacy back-compat quartet, malformed/missing inputs).
///
/// AG-5: split out of the former test/core/sync/codecs_and_mergers_test.dart
/// (AUD-app-05) so this file mirrors
/// lib/core/sync/codec/stage_definition_codec.dart 1:1. UiPreferencesMerger's
/// tests moved to test/core/sync/merge/ui_preferences_merger_test.dart.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

DateTime _dt(int year, [int month = 1, int day = 1]) =>
    DateTime.utc(year, month, day);

const _codec = StageDefinitionCodec();

StageDefinitionRow _minimalRow({
  String curriculumId = 'bavli',
  int trackId = 1,
  int stageOrder = 0,
  String stageName = 'Stage 1',
  String schedule = '{"type":"delay","delay_days":7}',
  bool isDefault = false,
  DateTime? updatedAt,
  DateTime? syncedAt,
}) => StageDefinitionRow(
  curriculumId: curriculumId,
  trackId: trackId,
  stageOrder: stageOrder,
  stageName: stageName,
  schedule: schedule,
  isDefault: isDefault,
  updatedAt: updatedAt,
  syncedAt: syncedAt,
);

void main() {
  group('StageDefinitionCodec — kind', () {
    test('kind is "stage_definition"', () {
      expect(_codec.kind, EntityKind.stageDefinition);
    });
  });

  group('StageDefinitionCodec — encode → decode round-trip', () {
    test('delay schedule round-trips correctly', () {
      final row = _minimalRow(
        schedule: '{"type":"delay","delay_days":7}',
        updatedAt: _dt(2026),
      );
      final encoded = _codec.encode(row);
      final decoded = _codec.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, 'bavli');
      expect(decoded.trackId, 1);
      expect(decoded.stageOrder, 0);
      expect(decoded.stageName, 'Stage 1');
      expect(decoded.isDefault, isFalse);
      // schedule round-trips as the same JSON string
      expect(jsonDecode(decoded.schedule), {'type': 'delay', 'delay_days': 7});
    });

    test('days_of_week schedule round-trips correctly', () {
      final row = _minimalRow(
        schedule: '{"type":"days_of_week","days":[0,1,3,5]}',
      );
      final encoded = _codec.encode(row);
      final decoded = _codec.decode(encoded)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'days_of_week');
      expect(sched['days'], [0, 1, 3, 5]);
    });

    test('rolling_window schedule round-trips correctly', () {
      final row = _minimalRow(
        schedule: '{"type":"rolling_window","window_size":14}',
      );
      final encoded = _codec.encode(row);
      final decoded = _codec.decode(encoded)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'rolling_window');
      expect(sched['window_size'], 14);
    });

    test('isDefault=true round-trips correctly', () {
      final row = _minimalRow(isDefault: true);
      final decoded = _codec.decode(_codec.encode(row))!;
      expect(decoded.isDefault, isTrue);
    });

    test('updatedAt ISO-8601 string round-trips to UTC DateTime', () {
      final ts = DateTime.utc(2026, 3, 15, 12, 30);
      final row = _minimalRow(updatedAt: ts);
      final encoded = _codec.encode(row);
      // encoded updated_at is an ISO-8601 String
      expect(encoded['updated_at'], isA<String>());
      final decoded = _codec.decode(encoded)!;
      expect(decoded.updatedAt, ts);
      expect(decoded.updatedAt!.isUtc, isTrue);
    });

    test('null updatedAt is omitted from encoded map', () {
      final row = _minimalRow(updatedAt: null);
      final encoded = _codec.encode(row);
      expect(encoded.containsKey('updated_at'), isFalse);
    });

    test('syncedAt is not present in encode output (server-only field)', () {
      final row = _minimalRow(syncedAt: _dt(2026));
      final encoded = _codec.encode(row);
      // syncedAt is set by the server — codec does not encode it for push
      expect(encoded.containsKey('synced_at'), isFalse);
    });

    test('stageOrder=0 is preserved (not dropped as falsy)', () {
      final row = _minimalRow(stageOrder: 0);
      final decoded = _codec.decode(_codec.encode(row))!;
      expect(decoded.stageOrder, 0);
    });

    test('large stageOrder round-trips correctly', () {
      final row = _minimalRow(stageOrder: 999, trackId: 42);
      final decoded = _codec.decode(_codec.encode(row))!;
      expect(decoded.stageOrder, 999);
      expect(decoded.trackId, 42);
    });

    test('schedule as Map (not String) in raw is JSON-encoded on decode', () {
      // Firestore may deliver schedule as a Map when it was stored as a map.
      final raw = {
        'curriculum_id': 'mishnayos',
        'track_id': 2,
        'stage_order': 1,
        'stage_name': 'Stage 2',
        'schedule': {'type': 'delay', 'delay_days': 3},
        'is_default': false,
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'delay');
      expect(sched['delay_days'], 3);
    });
  });

  group('StageDefinitionCodec — decode returns null for malformed inputs', () {
    test('returns null when curriculum_id is missing', () {
      final raw = {
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
      };
      expect(_codec.decode(raw), isNull);
    });

    test('returns null when track_id is missing', () {
      final raw = {
        'curriculum_id': 'bavli',
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
      };
      expect(_codec.decode(raw), isNull);
    });

    test('returns null when stage_order is missing', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'schedule': '{"type":"delay","delay_days":7}',
      };
      expect(_codec.decode(raw), isNull);
    });

    test('returns null for completely empty map', () {
      expect(_codec.decode({}), isNull);
    });

    test('returns null when track_id is unparseable string', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 'not-a-number',
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
      };
      expect(_codec.decode(raw), isNull);
    });

    test('returns null when stage_order is unparseable string', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 'bad',
        'schedule': '{"type":"delay","delay_days":7}',
      };
      expect(_codec.decode(raw), isNull);
    });
  });

  group('StageDefinitionCodec — legacy quartet back-compat', () {
    // When `schedule` key is absent (or null), codec falls back to the
    // legacy schedule_type / delay_days / days_of_week / rolling_window_size
    // quartet (W3.27 back-compat).

    test('legacy delay quartet produces delay schedule JSON', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'delay',
        'delay_days': 14,
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'delay');
      expect(sched['delay_days'], 14);
    });

    test('legacy delay quartet with missing delay_days defaults to 0', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'delay',
        // no delay_days
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['delay_days'], 0);
    });

    test('legacy days_of_week with JSON-string days_of_week', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'days_of_week',
        'days_of_week': '[1,3,5]',
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'days_of_week');
      expect(sched['days'], [1, 3, 5]);
    });

    test('legacy days_of_week with List days_of_week', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'days_of_week',
        'days_of_week': [0, 6],
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'days_of_week');
      expect(sched['days'], [0, 6]);
    });

    test(
      // AUD-core-sync-35 (EH-3): the malformed-days_of_week catch previously
      // swallowed the jsonDecode/cast failure with no AppLogger trail, so a
      // family's days_of_week schedule could silently collapse to [] with no
      // way to diagnose why. Fresh Talker per test so log history assertions
      // never see a prior test's entries (mirrors
      // completion_repository_siyum_detection_failure_test.dart).
      'legacy days_of_week with malformed JSON string logs the raw value '
      'via AppLogger before falling back to empty days',
      () {
        AppLogger.init();

        final raw = {
          'curriculum_id': 'bavli',
          'track_id': 1,
          'stage_order': 0,
          'schedule_type': 'days_of_week',
          'days_of_week': '{{bad json',
        };
        final decoded = _codec.decode(raw)!;
        final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
        expect(sched['type'], 'days_of_week');
        expect(sched['days'], isEmpty);

        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any(
            (m) =>
                m.contains('sync_stage_definition_malformed_days_of_week') &&
                m.contains('{{bad json'),
          ),
          isTrue,
          reason:
              'Expected the malformed days_of_week fallback to be logged '
              'via AppLogger (including the raw malformed value) instead of '
              'silently defaulting to []. Talker history: $history',
        );
      },
    );

    test('legacy days_of_week with null days_of_week produces empty days', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'days_of_week',
        // days_of_week absent → null
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'days_of_week');
      expect(sched['days'], isEmpty);
    });

    test('legacy rolling_window quartet produces rolling_window JSON', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'rolling_window',
        'rolling_window_size': 21,
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'rolling_window');
      expect(sched['window_size'], 21);
    });

    test('legacy rolling_window with missing size defaults to 7', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'rolling_window',
        // no rolling_window_size
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['window_size'], 7);
    });

    test('unknown schedule_type falls through to delay', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule_type': 'unknown_future_type',
        'delay_days': 5,
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'delay');
      expect(sched['delay_days'], 5);
    });

    test('absent schedule_type defaults to delay', () {
      // No schedule field, no schedule_type → defaults to delay.
      final raw = {'curriculum_id': 'bavli', 'track_id': 1, 'stage_order': 0};
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'delay');
      expect(sched['delay_days'], 0);
    });

    test('empty string schedule triggers legacy fallback (not kept as-is)', () {
      // Empty string schedule should fall through to legacy quartet.
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '',
        'schedule_type': 'delay',
        'delay_days': 3,
      };
      final decoded = _codec.decode(raw)!;
      final sched = jsonDecode(decoded.schedule) as Map<String, dynamic>;
      expect(sched['type'], 'delay');
      expect(sched['delay_days'], 3);
    });
  });

  group('StageDefinitionCodec — decode accepts various timestamp shapes', () {
    test('updated_at as DateTime object (SDK-parsed)', () {
      final ts = DateTime.utc(2026, 1, 1);
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
        'updated_at': ts,
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.updatedAt, ts);
    });

    test('updated_at as int (Unix epoch seconds)', () {
      const epochSeconds = 1700000000;
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
        'updated_at': epochSeconds,
      };
      final decoded = _codec.decode(raw)!;
      expect(
        decoded.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true),
      );
    });

    test('updated_at as Timestamp-like Map {seconds, nanoseconds}', () {
      const epochSeconds = 1700000000;
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
        'updated_at': {'seconds': epochSeconds, 'nanoseconds': 0},
      };
      final decoded = _codec.decode(raw)!;
      expect(
        decoded.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true),
      );
    });

    test('updated_at as ISO-8601 String', () {
      final ts = DateTime.utc(2026, 6, 1, 10, 0, 0);
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":7}',
        'updated_at': ts.toIso8601String(),
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.updatedAt, ts);
    });

    test('track_id as String is parsed to int', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': '3',
        'stage_order': '2',
        'schedule': '{"type":"delay","delay_days":0}',
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.trackId, 3);
      expect(decoded.stageOrder, 2);
    });

    test('is_default as int 1 is parsed to true', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":0}',
        'is_default': 1,
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.isDefault, isTrue);
    });

    test('is_default as String "true" is parsed to true', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":0}',
        'is_default': 'true',
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.isDefault, isTrue);
    });

    test('missing is_default defaults to false', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":0}',
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.isDefault, isFalse);
    });

    test('missing stage_name defaults to empty string', () {
      final raw = {
        'curriculum_id': 'bavli',
        'track_id': 1,
        'stage_order': 0,
        'schedule': '{"type":"delay","delay_days":0}',
      };
      final decoded = _codec.decode(raw)!;
      expect(decoded.stageName, '');
    });
  });
}
