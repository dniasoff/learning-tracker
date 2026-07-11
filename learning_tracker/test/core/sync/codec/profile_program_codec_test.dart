/// Unit tests for [ProfileProgramCodec]: encode<->decode round-trip and
/// required-field null-guards.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/profile_program_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = ProfileProgramCodec();
  final trackingStart = DateTime.utc(2026, 1, 1);
  final updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  group('ProfileProgramCodec — kind', () {
    test('kind is "profile_program"', () {
      expect(codec.kind, EntityKind.profileProgram);
    });
  });

  group('ProfileProgramCodec — encode → decode round-trip', () {
    test('round-trips all fields', () {
      final row = ProfileProgramRow(
        profileId: 1,
        curriculumId: 'bavli',
        programId: 2,
        trackingStartDate: trackingStart,
        trackingStartRef: 'Berakhot 2a',
        updatedAt: updatedAt,
      );
      final decoded = codec.decode(codec.encode(row));
      expect(decoded, isNotNull);
      expect(decoded!.profileId, 1);
      expect(decoded.curriculumId, 'bavli');
      expect(decoded.programId, 2);
      expect(decoded.trackingStartDate, trackingStart);
      expect(decoded.trackingStartRef, 'Berakhot 2a');
      expect(decoded.updatedAt, updatedAt);
    });

    test('optional fields are omitted from encode() output when null', () {
      final payload = codec.encode(
        const ProfileProgramRow(
          profileId: 1,
          curriculumId: 'bavli',
          programId: 2,
        ),
      );
      expect(payload.containsKey('tracking_start_date'), isFalse);
      expect(payload.containsKey('tracking_start_ref'), isFalse);
      expect(payload.containsKey('updated_at'), isFalse);
    });
  });

  group('ProfileProgramCodec — decode returns null for malformed inputs', () {
    test('missing profile_id', () {
      expect(codec.decode({'curriculum_id': 'bavli', 'program_id': 2}), isNull);
    });

    test('missing curriculum_id', () {
      expect(codec.decode({'profile_id': 1, 'program_id': 2}), isNull);
    });

    test('missing program_id', () {
      expect(codec.decode({'profile_id': 1, 'curriculum_id': 'bavli'}), isNull);
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('ProfileProgramCodec — legacy payload without updated_at', () {
    test(
      'decode succeeds without updated_at (falls back to tracking_start_date '
      'at the merger layer, not the codec)',
      () {
        final decoded = codec.decode({
          'profile_id': 1,
          'curriculum_id': 'bavli',
          'program_id': 2,
          'tracking_start_date': trackingStart.toIso8601String(),
        });
        expect(decoded, isNotNull);
        expect(decoded!.updatedAt, isNull);
        expect(decoded.trackingStartDate, trackingStart);
      },
    );
  });
}
