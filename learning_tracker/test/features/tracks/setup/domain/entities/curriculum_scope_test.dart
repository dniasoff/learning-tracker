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
/// R16 (DNI-484): the governed `updated_at` / `synced_at` are retired —
/// `toFirestore` never writes them and the decoder ignores them.
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
  );

  group('round-trip', () {
    test('curriculumId/scopeLevel/scopeValue/createdAt survive toFirestore -> '
        'fromFirestore', () {
      final decoded = curriculumScopeFromFirestore(base.toFirestore());

      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.scopeLevel, base.scopeLevel);
      expect(decoded.scopeValue, base.scopeValue);
      expect(decoded.createdAt, base.createdAt);
    });

    test('R16: a legacy document carrying the governed updated_at / '
        'synced_at decodes, and re-encoding drops both', () {
      final decoded = curriculumScopeFromFirestore({
        'curriculum_id': 'mishnayos',
        'scope_level': 1,
        'scope_value': 'Seder Zeraim',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-05T00:00:00.000Z',
        'synced_at': '2026-01-05T00:00:00.000Z',
      });

      final payload = decoded.toFirestore();
      expect(payload, isNot(contains('updated_at')));
      expect(payload, isNot(contains('synced_at')));
    });
  });

  group('field names match the firestore.rules `curriculum_scopes` shape '
      '(no .hasOnly() whitelist for this collection — intentionally '
      'open-ended)', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      final payload = base.toFirestore();

      expect(payload.keys.toSet(), <String>{
        'curriculum_id',
        'scope_level',
        'scope_value',
        'created_at',
      });
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test('toFirestore never writes profile_id (path-derived), track_id, or '
        'a Drift-style id', () {
      final payload = base.toFirestore();
      expect(payload, isNot(contains('profile_id')));
      expect(payload, isNot(contains('track_id')));
      expect(payload, isNot(contains('id')));
    });
  });

  group('created_at is an ISO-8601 String — documented-safe here: '
      'curriculum_scopes has no is-timestamp rules guard at all', () {
    test('toFirestore encodes created_at as String, not DateTime', () {
      final payload = base.toFirestore();
      expect(payload['created_at'], isA<String>());
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

    test('a governed doc without created_at decodes (DNI-476: governed '
        'writes carry only the AD-52 keys)', () {
      final data = validMap()..remove('created_at');
      expect(curriculumScopeFromFirestore(data).createdAt, DateTime.utc(1970));
    });

    test('a fully valid map decodes without throwing', () {
      expect(() => curriculumScopeFromFirestore(validMap()), returnsNormally);
    });
  });
}
