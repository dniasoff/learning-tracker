/// Unit tests for [TrackCodec]: encode<->decode round-trip, required-field
/// null-guards, and the state / is_active back-compat fallback.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/track_config_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = TrackCodec();
  final activatedAt = DateTime.utc(2026, 1, 1);
  final stateChangedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  group('TrackCodec — kind', () {
    test('kind is "track_config"', () {
      expect(codec.kind, EntityKind.trackConfig);
    });
  });

  group('TrackCodec — encode → decode round-trip', () {
    test('round-trips all fields', () {
      final row = TrackRow(
        profileId: 7,
        trackId: 42,
        curriculumId: 'bavli',
        state: 'active',
        activatedAt: activatedAt,
        stateChangedAt: stateChangedAt,
        paceResetDate: DateTime.utc(2026, 3, 15),
      );
      final decoded = codec.decode(codec.encode(row));
      expect(decoded, isNotNull);
      expect(decoded!.profileId, 7);
      expect(decoded.trackId, 42);
      expect(decoded.curriculumId, 'bavli');
      expect(decoded.state, 'active');
      expect(decoded.activatedAt, activatedAt);
      expect(decoded.stateChangedAt, stateChangedAt);
      expect(decoded.paceResetDate, DateTime.utc(2026, 3, 15));
    });

    test(
      'encode() emits profile_id and track_id (Phase B canonical fields)',
      () {
        final payload = codec.encode(
          TrackRow(
            profileId: 7,
            trackId: 42,
            curriculumId: 'bavli',
            state: 'active',
            activatedAt: activatedAt,
            stateChangedAt: stateChangedAt,
          ),
        );
        expect(payload['profile_id'], 7);
        expect(payload['track_id'], 42);
      },
    );

    test('pace_reset_date is omitted from encode() output when null', () {
      final payload = codec.encode(
        TrackRow(
          profileId: 1,
          trackId: 1,
          curriculumId: 'bavli',
          state: 'active',
          activatedAt: activatedAt,
          stateChangedAt: stateChangedAt,
        ),
      );
      expect(payload.containsKey('pace_reset_date'), isFalse);
    });
  });

  group('TrackCodec — decode returns null for malformed inputs', () {
    test('missing curriculum_id', () {
      expect(
        codec.decode({'activated_at': activatedAt.toIso8601String()}),
        isNull,
      );
    });

    test('missing activated_at', () {
      expect(codec.decode({'curriculum_id': 'bavli'}), isNull);
    });

    test('empty map', () {
      expect(codec.decode(const {}), isNull);
    });
  });

  group('TrackCodec — state back-compat fallback', () {
    test('explicit state field is used when present', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
        'state': 'retired',
      });
      expect(decoded?.state, 'retired');
    });

    test('is_active=true maps to state "active" when state is absent', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
        'is_active': true,
      });
      expect(decoded?.state, 'active');
    });

    test('is_active=false maps to state "retired" when state is absent', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
        'is_active': false,
      });
      expect(decoded?.state, 'retired');
    });

    test('missing both state and is_active defaults to "active"', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
      });
      expect(decoded?.state, 'active');
    });
  });

  group('TrackCodec — stateChangedAt fallback chain', () {
    test('state_changed_at is used when present', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
        'state_changed_at': stateChangedAt.toIso8601String(),
      });
      expect(decoded?.stateChangedAt, stateChangedAt);
    });

    test('deactivated_at is a fallback when state_changed_at is absent', () {
      final deactivatedAt = DateTime.utc(2026, 5, 1);
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
        'deactivated_at': deactivatedAt.toIso8601String(),
      });
      expect(decoded?.stateChangedAt, deactivatedAt);
    });

    test('falls back to activated_at when neither is present', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
      });
      expect(decoded?.stateChangedAt, activatedAt);
    });
  });

  group('TrackCodec — profile_id / track_id decode defaults', () {
    test('missing profile_id and track_id default to 0', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
      });
      expect(decoded?.profileId, 0);
      expect(decoded?.trackId, 0);
    });

    test('int profile_id / track_id are read as-is', () {
      final decoded = codec.decode({
        'curriculum_id': 'bavli',
        'activated_at': activatedAt.toIso8601String(),
        'profile_id': 9,
        'track_id': 11,
      });
      expect(decoded?.profileId, 9);
      expect(decoded?.trackId, 11);
    });

    // NOTE (candidate follow-up, out of scope for AUD-app-05): decode()'s
    // `raw['profile_id'] as int? ?? int.tryParse(...)` pattern documents an
    // intent to also accept a String profile_id/track_id, but `as int?`
    // throws a TypeError on a non-null String rather than evaluating to
    // null — so the int.tryParse(...) fallback is unreachable dead code.
    // Not exercised here since it is a behavioural defect, not a test-
    // mirroring gap.
  });
}
