/// Unit tests for
/// `lib/features/tracks/setup/domain/entities/curriculum_scope.dart` — the
/// pure-Dart `CurriculumScopeEntity` model and its `toFirestore`/
/// `curriculumScopeFromFirestore` codec functions. No `fake_cloud_firestore`
/// here: these are plain map round-trips, mirroring
/// `bookmark_entity_test.dart`'s style. Repository-level behavior (doc-id,
/// decode leniency in a live collection, `setScopes` clear-then-insert) is
/// already covered by
/// `test/data/repositories/firestore_curriculum_scope_repository_test.dart`.
///
/// **`toFirestore({required DateTime updatedAt})` ignores the entity's own
/// [CurriculumScopeEntity.updatedAt] field entirely** — confirmed
/// deliberate, not a bug, by reading
/// `FirestoreCurriculumScopeRepository` (`lib/data/repositories/
/// firestore_curriculum_scope_repository.dart`), which always calls
/// `entity.toFirestore(updatedAt: now)` with a fresh write-time clock value.
/// The entity's own nullable `updatedAt` field is decode-only: it reflects
/// "the `updated_at` this doc last decoded with" (`null` for a scope that
/// has never been touched since creation — see the field's own doc
/// comment), never an input to encoding. The round-trip test below encodes
/// with an explicit write-time value and asserts against THAT value, not
/// `base.updatedAt`, to avoid mis-modeling this as a bug.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_scope.dart';

void main() {
  final base = CurriculumScopeEntity(
    curriculumId: CurriculumId.mishnayos,
    scopeLevel: 1,
    scopeValue: 'Seder Zeraim',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 5),
  );

  group('round-trip', () {
    test('curriculumId/scopeLevel/scopeValue/createdAt survive toFirestore -> '
        'fromFirestore, and the write-time updatedAt param (not '
        'base.updatedAt) comes back', () {
      final writeTime = DateTime.utc(2026, 2, 1);
      final decoded = curriculumScopeFromFirestore(
        base.toFirestore(updatedAt: writeTime),
      );

      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.scopeLevel, base.scopeLevel);
      expect(decoded.scopeValue, base.scopeValue);
      expect(decoded.createdAt, base.createdAt);
      expect(decoded.updatedAt, writeTime);
    });

    test('a document with no updated_at key at all (never touched since '
        'creation) decodes to updatedAt: null — this is the realistic shape '
        'a bare insert (not routed through toFirestore) produces', () {
      final decoded = curriculumScopeFromFirestore({
        'curriculum_id': 'mishnayos',
        'scope_level': 1,
        'scope_value': 'Seder Zeraim',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(decoded.updatedAt, isNull);
    });
  });

  group('field names match the firestore.rules `curriculum_scopes` shape '
      '(no .hasOnly() whitelist for this collection — intentionally '
      'open-ended)', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      final payload = base.toFirestore(updatedAt: DateTime.utc(2026, 2, 1));

      expect(payload.keys.toSet(), <String>{
        'curriculum_id',
        'scope_level',
        'scope_value',
        'created_at',
        'updated_at',
      });
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test('toFirestore never writes profile_id (path-derived), track_id, or '
        'a Drift-style id', () {
      final payload = base.toFirestore(updatedAt: DateTime.utc(2026, 2, 1));
      expect(payload, isNot(contains('profile_id')));
      expect(payload, isNot(contains('track_id')));
      expect(payload, isNot(contains('id')));
    });
  });

  group('created_at/updated_at are ISO-8601 Strings — documented-safe here: '
      'curriculum_scopes has no is-timestamp rules guard at all', () {
    test('toFirestore encodes both date fields as String, not DateTime', () {
      final payload = base.toFirestore(updatedAt: DateTime.utc(2026, 2, 1));
      expect(payload['created_at'], isA<String>());
      expect(payload['updated_at'], isA<String>());
    });
  });

  group('curriculumScopeFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'curriculum_id': 'mishnayos',
      'scope_level': 1,
      'scope_value': 'Seder Zeraim',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-05T00:00:00.000Z',
    };

    test('throws ArgumentError for an unrecognised curriculum_id', () {
      final data = validMap()..['curriculum_id'] = 'not-a-real-curriculum';
      expect(
        () => curriculumScopeFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when curriculum_id is missing entirely', () {
      final data = validMap()..remove('curriculum_id');
      expect(
        () => curriculumScopeFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when scope_level is missing', () {
      final data = validMap()..remove('scope_level');
      expect(
        () => curriculumScopeFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when scope_value is missing', () {
      final data = validMap()..remove('scope_value');
      expect(
        () => curriculumScopeFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when created_at is missing', () {
      final data = validMap()..remove('created_at');
      expect(
        () => curriculumScopeFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('a fully valid map decodes without throwing', () {
      expect(() => curriculumScopeFromFirestore(validMap()), returnsNormally);
    });
  });
}
