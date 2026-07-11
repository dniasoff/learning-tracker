/// Unit tests for [StreakEventCodec]: encode<->decode round-trip and
/// required-field null-guards.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/streak_event_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = StreakEventCodec();
  final studyDate = DateTime.utc(2026, 6, 18);
  final createdAt = DateTime.utc(2026, 6, 18, 14, 30, 0);

  group('StreakEventCodec — kind', () {
    test('kind is "streak"', () {
      expect(codec.kind, EntityKind.streak);
    });
  });

  group('StreakEventCodec — encode → decode round-trip', () {
    test('round-trips required fields', () {
      final row = StreakEventRow(
        profileId: 1,
        eventType: 'completion',
        studyDate: studyDate,
        createdAt: createdAt,
        ulid: 'ULID1',
      );
      final decoded = codec.decode(codec.encode(row));
      expect(decoded, isNotNull);
      expect(decoded!.profileId, 1);
      expect(decoded.eventType, 'completion');
      expect(decoded.studyDate, studyDate);
      expect(decoded.createdAt, createdAt);
      expect(decoded.ulid, 'ULID1');
    });

    test('ulid is omitted from encode() output when null (optional field)', () {
      final payload = codec.encode(
        StreakEventRow(
          profileId: 1,
          eventType: 'completion',
          studyDate: studyDate,
          createdAt: createdAt,
        ),
      );
      expect(payload.containsKey('ulid'), isFalse);
    });
  });

  group('StreakEventCodec — decode returns null for malformed inputs', () {
    final validRaw = {
      'profile_id': 1,
      'event_type': 'completion',
      'study_date': studyDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };

    test('valid input decodes', () {
      expect(codec.decode(validRaw), isNotNull);
    });

    test('missing profile_id', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('profile_id');
      expect(codec.decode(raw), isNull);
    });

    test('missing event_type', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('event_type');
      expect(codec.decode(raw), isNull);
    });

    test('missing study_date', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('study_date');
      expect(codec.decode(raw), isNull);
    });

    test('missing created_at', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('created_at');
      expect(codec.decode(raw), isNull);
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('StreakEventCodec — decode ulid is optional', () {
    test('decode succeeds without ulid', () {
      final decoded = codec.decode({
        'profile_id': 1,
        'event_type': 'completion',
        'study_date': studyDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      });
      expect(decoded, isNotNull);
      expect(decoded!.ulid, isNull);
    });
  });
}
