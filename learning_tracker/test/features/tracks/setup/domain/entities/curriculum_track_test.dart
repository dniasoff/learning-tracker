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
/// DNI-484 (R16): the codec carries only the live fields — `curriculum_id`,
/// `state` and the display-only `activated_at`. The retired fields (the
/// lifecycle and purge stamps, the pace reset, the reorder baseline, the
/// progress passthrough and the governed timestamps, read from the AD-49
/// inventory, DNI-489) are never encoded and never surfaced on decode.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

import '../../../../../helpers/retired_inventory.dart';

/// The firestore.rules `curriculum_tracks` `.hasOnly()` whitelist after R16.
const _rulesWhitelist = <String>{
  'profile_id',
  'track_id',
  'curriculum_id',
  'state',
  'activated_at',
  'last_change_id',
  'ended_at',
};

/// Every R16 retired `curriculum_tracks` key, from the AD-49 inventory.
final _retiredKeys = retiredKeysOf(
  'lib/features/tracks/setup/domain/entities/curriculum_track.dart',
);

void main() {
  final base = CurriculumTrackEntity(
    curriculumId: CurriculumId.chumash,
    state: CurriculumTrackState.active.storageKey,
    activatedAt: DateTime.utc(2026, 1, 1),
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
        );
        expect(entity.isActive, isFalse, reason: 'state=$state');
      }
    });
  });

  group('round-trip', () {
    test('curriculum_id, state and activated_at survive toFirestore -> '
        'fromFirestore', () {
      final decoded = curriculumTrackFromFirestore(base.toFirestore());

      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.state, base.state);
      expect(decoded.activatedAt, base.activatedAt);
    });

    test('an unrecognised state string round-trips as-is — decode does not '
        'validate the VALUE, only that the key is present', () {
      final decoded = curriculumTrackFromFirestore({
        'curriculum_id': 'chumash',
        'state': 'some-future-state',
      });

      expect(decoded.state, 'some-future-state');
      expect(decoded.isActive, isFalse);
    });
  });

  group('R16 retired fields (DNI-484)', () {
    test('a minimal document (state only, no activated_at, no retired '
        'field) decodes; activatedAt is null', () {
      final decoded = curriculumTrackFromFirestore({
        'curriculum_id': 'bavli',
        'state': 'retired',
      });
      expect(decoded.state, 'retired');
      expect(decoded.activatedAt, isNull);
    });

    test('a track without activated_at encodes no activated_at key', () {
      final payload = const CurriculumTrackEntity(
        curriculumId: CurriculumId.bavli,
        state: 'active',
      ).toFirestore();
      expect(payload.keys.toSet(), {'curriculum_id', 'state'});
    });

    test('a legacy document carrying every retired field at once decodes, '
        'and re-encoding it drops every retired key', () {
      final legacy = <String, dynamic>{
        'curriculum_id': 'nach',
        'state': 'active',
        'activated_at': '2026-01-04T00:00:00.000Z',
        ...legacyKeys(_retiredKeys),
      };
      final decoded = curriculumTrackFromFirestore(legacy);
      expect(decoded.state, 'active');
      expect(decoded.activatedAt, DateTime.utc(2026, 1, 4));

      final payload = decoded.toFirestore();
      for (final key in _retiredKeys) {
        expect(payload, isNot(contains(key)), reason: key);
      }
    });

    test('a retired key (the pace reset among them) can never be encoded: '
        'no entity field or constructor parameter carries one', () {
      final payload = base.toFirestore();
      for (final key in _retiredKeys) {
        expect(payload, isNot(contains(key)), reason: key);
      }
      expect(payload.keys.toSet(), {'curriculum_id', 'state', 'activated_at'});
    });
  });

  group('field names match the firestore.rules `curriculum_tracks` '
      '.hasOnly() whitelist', () {
    test('toFirestore emits exactly the live snake_case keys', () {
      expect(base.toFirestore().keys.toSet(), <String>{
        'curriculum_id',
        'state',
        'activated_at',
      });
    });

    test('every key toFirestore can ever emit is inside the rules '
        '.hasOnly() whitelist, and no retired key is in it', () {
      expect(_rulesWhitelist.containsAll(base.toFirestore().keys), isTrue);
      for (final key in _retiredKeys) {
        expect(_rulesWhitelist, isNot(contains(key)), reason: key);
      }
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

  group('activated_at is an ISO-8601 String — documented-safe here: '
      'curriculum_tracks has no is-timestamp rules guard', () {
    test('toFirestore encodes activated_at as String, not DateTime', () {
      expect(base.toFirestore()['activated_at'], isA<String>());
    });
  });

  group('curriculumTrackFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'curriculum_id': 'chumash',
      'state': 'active',
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

    test('a missing activated_at is not an error (display-only field)', () {
      final data = validMap()..remove('activated_at');
      expect(curriculumTrackFromFirestore(data).activatedAt, isNull);
    });

    test('a fully valid map decodes without throwing', () {
      expect(() => curriculumTrackFromFirestore(validMap()), returnsNormally);
    });
  });
}
