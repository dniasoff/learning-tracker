/// Unit tests for
/// `lib/features/tracks/setup/domain/entities/curriculum_track.dart` — the
/// pure-Dart `CurriculumTrackEntity` model, `CurriculumTrackState` enum, and
/// `toFirestore`/`curriculumTrackFromFirestore` codec functions. No
/// `fake_cloud_firestore` here: these are plain map round-trips, mirroring
/// `profile_program_test.dart`'s style. Repository-level behavior (doc-id,
/// the activate/retire/archive state machine, the last-active-curriculum
/// guard, decode leniency in a live collection) is covered by
/// `test/data/repositories/firestore_curriculum_track_repository_test.dart`.
///
/// `curriculum_tracks` has a real `.hasOnly()` field whitelist
/// (`firestore.rules`, `match /curriculum_tracks/{trackId}`): `profile_id`,
/// `track_id`, `curriculum_id`, `state`, `state_changed_at`, `activated_at`,
/// `pace_reset_date`, `progress_schema_version`, `progress_computed_at`,
/// `progress_model`, `program_progress`, `self_paced_progress`, `synced_at`,
/// `purged`, `purged_at`. The field-name test below asserts `toFirestore`'s
/// key set is a subset of exactly that list — a key outside it would be
/// silently accepted by every local test (`fake_cloud_firestore`'s rules
/// companion cannot evaluate `request.resource`) while failing with
/// permission-denied in production.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

/// The exact firestore.rules `curriculum_tracks` `.hasOnly()` whitelist.
const _rulesWhitelist = <String>{
  'profile_id',
  'track_id',
  'curriculum_id',
  'state',
  'state_changed_at',
  'activated_at',
  'pace_reset_date',
  'progress_schema_version',
  'progress_computed_at',
  'progress_model',
  'program_progress',
  'self_paced_progress',
  'synced_at',
  'purged',
  'purged_at',
};

void main() {
  final base = CurriculumTrackEntity(
    curriculumId: CurriculumId.chumash,
    state: CurriculumTrackState.active.storageKey,
    stateChangedAt: DateTime.utc(2026, 1, 1),
    activatedAt: DateTime.utc(2026, 1, 1),
    paceResetDate: DateTime.utc(2026, 1, 2),
  );

  group('CurriculumTrackState', () {
    test('fromStorageKey resolves the three known values', () {
      expect(
        CurriculumTrackState.fromStorageKey('active'),
        CurriculumTrackState.active,
      );
      expect(
        CurriculumTrackState.fromStorageKey('retired'),
        CurriculumTrackState.retired,
      );
      expect(
        CurriculumTrackState.fromStorageKey('archived'),
        CurriculumTrackState.archived,
      );
    });

    test('fromStorageKey returns null for the retired Drift "deleted" value '
        'and for any unrecognised string', () {
      expect(CurriculumTrackState.fromStorageKey('deleted'), isNull);
      expect(CurriculumTrackState.fromStorageKey('not-a-real-state'), isNull);
    });
  });

  group('CurriculumTrackEntity.isActive', () {
    test('true only for the known active storageKey', () {
      expect(base.isActive, isTrue);
    });

    test('false for retired/archived/unrecognised strings', () {
      for (final state in ['retired', 'archived', 'deleted', 'bogus']) {
        final entity = CurriculumTrackEntity(
          curriculumId: CurriculumId.chumash,
          state: state,
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.isActive, isFalse, reason: 'state=$state');
      }
    });
  });

  group('round-trip', () {
    test('every field survives toFirestore -> fromFirestore, including '
        'paceResetDate', () {
      final decoded = curriculumTrackFromFirestore(base.toFirestore());

      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.state, base.state);
      expect(decoded.stateChangedAt, base.stateChangedAt);
      expect(decoded.activatedAt, base.activatedAt);
      expect(decoded.paceResetDate, base.paceResetDate);
    });

    test('no paceResetDate: field is omitted from the payload and decodes '
        'back to null', () {
      final neverReset = CurriculumTrackEntity(
        curriculumId: CurriculumId.bavli,
        state: CurriculumTrackState.active.storageKey,
        stateChangedAt: DateTime.utc(2026, 1, 3),
        activatedAt: DateTime.utc(2026, 1, 3),
      );

      final payload = neverReset.toFirestore();
      expect(payload, isNot(contains('pace_reset_date')));

      final decoded = curriculumTrackFromFirestore(payload);
      expect(decoded.paceResetDate, isNull);
    });

    test('an unrecognised state string round-trips as-is — decode does not '
        'validate the VALUE, only that the key is present', () {
      final decoded = curriculumTrackFromFirestore({
        'curriculum_id': 'chumash',
        'state': 'some-future-state',
        'state_changed_at': '2026-01-01T00:00:00.000Z',
        'activated_at': '2026-01-01T00:00:00.000Z',
      });

      expect(decoded.state, 'some-future-state');
      expect(decoded.isActive, isFalse);
    });

    test('progress passthrough fields (schema_version/computed_at/model/'
        'program_progress/self_paced_progress) and syncedAt are decode-only '
        '— never written by toFirestore even when set on the entity, but '
        'decode back when the document already has them (e.g. a future '
        'progress-writer or a tutor-CF-stamped synced_at)', () {
      final withPassthrough = CurriculumTrackEntity(
        curriculumId: CurriculumId.nach,
        state: CurriculumTrackState.active.storageKey,
        stateChangedAt: DateTime.utc(2026, 1, 4),
        activatedAt: DateTime.utc(2026, 1, 4),
        progressSchemaVersion: 1,
        progressComputedAt: DateTime.utc(2026, 1, 5),
        progressModel: 'self_paced',
        programProgress: {'percent': 42},
        selfPacedProgress: {'percent': 42},
        syncedAt: DateTime.utc(2026, 1, 6),
      );

      final payload = withPassthrough.toFirestore();
      for (final key in [
        'progress_schema_version',
        'progress_computed_at',
        'progress_model',
        'program_progress',
        'self_paced_progress',
        'synced_at',
      ]) {
        expect(payload, isNot(contains(key)), reason: key);
      }

      final decoded = curriculumTrackFromFirestore({
        ...payload,
        'progress_schema_version': 2,
        'progress_computed_at': '2026-01-07T00:00:00.000Z',
        'progress_model': 'program',
        'program_progress': {'percent': 7},
        'self_paced_progress': {'percent': 9},
        'synced_at': '2026-01-08T00:00:00.000Z',
      });
      expect(decoded.progressSchemaVersion, 2);
      expect(decoded.progressComputedAt, DateTime.utc(2026, 1, 7));
      expect(decoded.progressModel, 'program');
      expect(decoded.programProgress, {'percent': 7});
      expect(decoded.selfPacedProgress, {'percent': 9});
      expect(decoded.syncedAt, DateTime.utc(2026, 1, 8));
    });
  });

  group('field names match the firestore.rules `curriculum_tracks` '
      '.hasOnly() whitelist', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      expect(base.toFirestore().keys.toSet(), <String>{
        'curriculum_id',
        'state',
        'state_changed_at',
        'activated_at',
        'pace_reset_date',
      });
    });

    test('every key toFirestore can ever emit is inside the rules '
        '.hasOnly() whitelist', () {
      final full = base.toFirestore();
      final minimal = CurriculumTrackEntity(
        curriculumId: CurriculumId.bavli,
        state: CurriculumTrackState.retired.storageKey,
        stateChangedAt: DateTime.utc(2026, 1, 1),
        activatedAt: DateTime.utc(2026, 1, 1),
      ).toFirestore();

      expect(_rulesWhitelist.containsAll(full.keys), isTrue);
      expect(_rulesWhitelist.containsAll(minimal.keys), isTrue);
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test('toFirestore never writes profile_id or track_id — path already '
        'carries profile identity, track_id is the retired per-device key', () {
      final payload = base.toFirestore();
      expect(payload, isNot(contains('profile_id')));
      expect(payload, isNot(contains('track_id')));
    });
  });

  group('state_changed_at/activated_at/pace_reset_date are ISO-8601 Strings '
      '— documented-safe here: curriculum_tracks has no is-timestamp rules '
      'guard at all (unlike completions/streak_events/learning_ledger/'
      'points_ledger)', () {
    test('toFirestore encodes all three date fields as String, not '
        'DateTime', () {
      final payload = base.toFirestore();
      expect(payload['state_changed_at'], isA<String>());
      expect(payload['activated_at'], isA<String>());
      expect(payload['pace_reset_date'], isA<String>());
    });
  });

  group('curriculumTrackFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'curriculum_id': 'chumash',
      'state': 'active',
      'state_changed_at': '2026-01-01T00:00:00.000Z',
      'activated_at': '2026-01-01T00:00:00.000Z',
    };

    test('throws ArgumentError for an unrecognised curriculum_id', () {
      final data = validMap()..['curriculum_id'] = 'not-a-real-curriculum';
      expect(
        () => curriculumTrackFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when curriculum_id is missing entirely', () {
      final data = validMap()..remove('curriculum_id');
      expect(
        () => curriculumTrackFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when state is missing', () {
      final data = validMap()..remove('state');
      expect(
        () => curriculumTrackFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when state is empty', () {
      final data = validMap()..['state'] = '';
      expect(
        () => curriculumTrackFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when state_changed_at is missing', () {
      final data = validMap()..remove('state_changed_at');
      expect(
        () => curriculumTrackFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when activated_at is missing', () {
      final data = validMap()..remove('activated_at');
      expect(
        () => curriculumTrackFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('a fully valid map decodes without throwing', () {
      expect(() => curriculumTrackFromFirestore(validMap()), returnsNormally);
    });
  });
}
