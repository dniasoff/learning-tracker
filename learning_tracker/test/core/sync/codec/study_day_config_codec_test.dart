/// Unit tests for [StudyDayConfigCodec]: encode<->decode round-trip and
/// required-field null-guards.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/study_day_config_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/study_day_config_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = StudyDayConfigCodec();
  final updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  group('StudyDayConfigCodec — kind', () {
    test('kind is "study_day_config"', () {
      expect(codec.kind, EntityKind.studyDayConfig);
    });
  });

  group('StudyDayConfigCodec — encode → decode round-trip', () {
    test('round-trips all fields', () {
      final row = StudyDayConfigRow(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: 5,
        dayOfWeek: 1,
        dayType: 'study',
        updatedAt: updatedAt,
      );
      final decoded = codec.decode(codec.encode(row));
      expect(decoded, isNotNull);
      expect(decoded!.profileId, 1);
      expect(decoded.curriculumId, 'bavli');
      expect(decoded.trackId, 5);
      expect(decoded.dayOfWeek, 1);
      expect(decoded.dayType, 'study');
      expect(decoded.updatedAt, updatedAt);
    });

    test('dayOfWeek=0 (Sunday) is preserved, not dropped as falsy', () {
      final row = StudyDayConfigRow(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: 5,
        dayOfWeek: 0,
        dayType: 'review',
        updatedAt: updatedAt,
      );
      expect(codec.decode(codec.encode(row))?.dayOfWeek, 0);
    });
  });

  group('StudyDayConfigCodec — decode returns null for malformed inputs', () {
    final validRaw = {
      'profile_id': 1,
      'curriculum_id': 'bavli',
      'track_id': 5,
      'day_of_week': 1,
      'day_type': 'study',
      'updated_at': updatedAt.toIso8601String(),
    };

    test('valid input decodes', () {
      expect(codec.decode(validRaw), isNotNull);
    });

    for (final key in [
      'profile_id',
      'curriculum_id',
      'track_id',
      'day_of_week',
      'day_type',
      'updated_at',
    ]) {
      test('missing $key', () {
        final raw = Map<String, dynamic>.from(validRaw)..remove(key);
        expect(codec.decode(raw), isNull);
      });
    }

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });
}
