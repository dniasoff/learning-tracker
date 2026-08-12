/// Unit tests for
/// `lib/features/tracks/setup/domain/entities/profile_program.dart` — the
/// pure-Dart `ProfileProgramEntity` model and its
/// `toFirestore`/`profileProgramFromFirestore` codec functions. No
/// `fake_cloud_firestore` here: these are plain map round-trips, mirroring
/// `bookmark_entity_test.dart`'s style. Repository-level behavior (doc-id,
/// the `SetOptions(merge: true)` field-clearing trap, decode leniency in a
/// live collection) is already covered by
/// `test/data/repositories/firestore_profile_program_repository_test.dart`.
///
/// **`profile_programs` is the one of these four collections with a real
/// `.hasOnly()` field whitelist** (`firestore.rules`, `match
/// /profile_programs/{curriculumId}`): `profile_id`, `curriculum_id`,
/// `program_id`, `tracking_start_date`, `tracking_start_ref`, `synced_at`,
/// `updated_at`. The field-name test below asserts `toFirestore`'s key set
/// is a subset of exactly that list — a key outside it would be silently
/// accepted by every local test (`fake_cloud_firestore`'s rules companion
/// cannot evaluate `request.resource`) while failing with permission-denied
/// in production.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';

/// The exact firestore.rules `profile_programs` `.hasOnly()` whitelist.
const _rulesWhitelist = <String>{
  'profile_id',
  'curriculum_id',
  'program_id',
  'tracking_start_date',
  'tracking_start_ref',
  'synced_at',
  'updated_at',
};

void main() {
  final base = ProfileProgramEntity(
    curriculumId: CurriculumId.chumash,
    programId: 7,
    trackingStartDate: DateTime.utc(2026, 1, 1),
    trackingStartRef: 'Genesis.1.1',
    updatedAt: DateTime.utc(2026, 1, 2),
  );

  group('round-trip', () {
    test('every field survives toFirestore -> fromFirestore, including the '
        'tracking window', () {
      final decoded = profileProgramFromFirestore(
        base.toFirestore(profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB'),
      );

      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.programId, base.programId);
      expect(decoded.trackingStartDate, base.trackingStartDate);
      expect(decoded.trackingStartRef, base.trackingStartRef);
      expect(decoded.updatedAt, base.updatedAt);
    });

    test('no tracking window: both fields are omitted from the payload and '
        'decode back to null', () {
      final noWindow = ProfileProgramEntity(
        curriculumId: CurriculumId.bavli,
        programId: 3,
        updatedAt: DateTime.utc(2026, 1, 3),
      );

      final payload = noWindow.toFirestore(
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );
      expect(payload, isNot(contains('tracking_start_date')));
      expect(payload, isNot(contains('tracking_start_ref')));

      final decoded = profileProgramFromFirestore(payload);
      expect(decoded.trackingStartDate, isNull);
      expect(decoded.trackingStartRef, isNull);
    });

    test('syncedAt is decode-only — never written by toFirestore even when '
        'set on the entity, but decodes back when the doc already has it '
        '(e.g. a tutor-CF-stamped value)', () {
      final withSynced = ProfileProgramEntity(
        curriculumId: CurriculumId.nach,
        programId: 1,
        updatedAt: DateTime.utc(2026, 1, 4),
        syncedAt: DateTime.utc(2026, 1, 5),
      );

      final payload = withSynced.toFirestore(
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );
      expect(
        payload,
        isNot(contains('synced_at')),
        reason:
            'the repository doc comment: "client-supplied synced_at is '
            'never written — see the repository\'s toFirestore caller"',
      );

      final decoded = profileProgramFromFirestore({
        ...payload,
        'synced_at': '2026-01-06T00:00:00.000Z',
      });
      expect(decoded.syncedAt, DateTime.utc(2026, 1, 6));
    });
  });

  group('field names match the firestore.rules `profile_programs` .hasOnly() '
      'whitelist', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      final payload = base.toFirestore(
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );

      expect(payload.keys.toSet(), <String>{
        'profile_id',
        'curriculum_id',
        'program_id',
        'tracking_start_date',
        'tracking_start_ref',
        'updated_at',
      });
    });

    test('every key toFirestore can ever emit is inside the rules '
        '.hasOnly() whitelist', () {
      final full = base.toFirestore(
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );
      final minimal = ProfileProgramEntity(
        curriculumId: CurriculumId.bavli,
        programId: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
      ).toFirestore(profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB');

      expect(_rulesWhitelist.containsAll(full.keys), isTrue);
      expect(_rulesWhitelist.containsAll(minimal.keys), isTrue);
    });

    test('profile_id is written as the String profileId param', () {
      expect(
        base.toFirestore(
          profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
        )['profile_id'],
        '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test('toFirestore never writes track_id or a Drift-style id', () {
      final payload = base.toFirestore(
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );
      expect(payload, isNot(contains('track_id')));
      expect(payload, isNot(contains('id')));
    });
  });

  group('tracking_start_date/updated_at are ISO-8601 Strings — documented-safe '
      'here: profile_programs has no is-timestamp rules guard at all', () {
    test('toFirestore encodes both date fields as String, not DateTime', () {
      final payload = base.toFirestore(
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      );
      expect(payload['tracking_start_date'], isA<String>());
      expect(payload['updated_at'], isA<String>());
    });
  });

  group('profileProgramFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'profile_id': '01J6Q2H4A8M7K3P9R5T6V8WXYB',
      'curriculum_id': 'chumash',
      'program_id': 7,
      'tracking_start_date': '2026-01-01T00:00:00.000Z',
      'tracking_start_ref': 'Genesis.1.1',
      'updated_at': '2026-01-02T00:00:00.000Z',
    };

    test('throws ArgumentError for an unrecognised curriculum_id', () {
      final data = validMap()..['curriculum_id'] = 'not-a-real-curriculum';
      expect(
        () => profileProgramFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when curriculum_id is missing entirely', () {
      final data = validMap()..remove('curriculum_id');
      expect(
        () => profileProgramFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when program_id is missing', () {
      final data = validMap()..remove('program_id');
      expect(
        () => profileProgramFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when updated_at is missing', () {
      final data = validMap()..remove('updated_at');
      expect(
        () => profileProgramFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('a fully valid map decodes without throwing', () {
      expect(() => profileProgramFromFirestore(validMap()), returnsNormally);
    });
  });
}
