/// Unit tests for
/// `lib/features/learning/domain/entities/completion_entity.dart` — the
/// pure-Dart `CompletionEntity` model and its
/// `CompletionEntityFirestoreCodec.toFirestore`/
/// `completionEntityFromFirestore` codec functions. No `fake_cloud_firestore`
/// here: these are plain map round-trips, mirroring
/// `learning_ledger_entry_test.dart`'s style. Repository-level behavior
/// (doc-id, idempotent replay, decode leniency in a live collection) is
/// covered by
/// `test/data/repositories/firestore_completion_repository_test.dart`.
///
/// **`completed_at` matters most here.** `firestore.rules`' `completions`
/// create rule compares `completed_at <= request.time`, and a Firestore
/// rules comparison between a `string` and a `timestamp` evaluates to
/// **deny** — the model's own class doc comment calls this out as the
/// single highest-stakes line in the whole repository. `toFirestore` writes
/// `completedAt.toUtc()` directly (a raw `DateTime`), NOT
/// `FirestoreCodec.encodeDateTime(completedAt)`. Verified below.
///
/// **`source == lifetimeOnly` must never decode successfully** — that value
/// must never reach this collection at all (see the model's class doc
/// comment); [completionEntityFromFirestore] throws for it rather than
/// silently accepting a document that should not exist.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

void main() {
  final base = CompletionEntity(
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: 'Berakhot 1:1',
    stageId: 2,
    trackType: 'personal',
    source: CompletionSource.live,
    completedAt: DateTime.utc(2026, 3, 1, 12),
    points: 10,
  );

  group('round-trip', () {
    test('every field survives toFirestore -> fromFirestore', () {
      final decoded = completionEntityFromFirestore(base.toFirestore());

      expect(decoded.curriculumId, base.curriculumId);
      expect(decoded.sefariaRef, base.sefariaRef);
      expect(decoded.stageId, base.stageId);
      expect(decoded.trackType, base.trackType);
      expect(decoded.source, base.source);
      expect(decoded.completedAt, base.completedAt);
      expect(decoded.points, base.points);
    });

    test('a bulkInTrack completion round-trips its source', () {
      final bulk = CompletionEntity(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Bava Kama 2a',
        stageId: 1,
        trackType: 'personal',
        source: CompletionSource.bulkInTrack,
        completedAt: DateTime.utc(2000, 1, 1),
        points: 0,
      );

      final decoded = completionEntityFromFirestore(bulk.toFirestore());
      expect(decoded.source, CompletionSource.bulkInTrack);
      expect(decoded.points, 0);
    });
  });

  group('field names match the firestore.rules `completions` shape', () {
    test('toFirestore emits exactly the expected snake_case keys', () {
      final payload = base.toFirestore();

      expect(payload.keys.toSet(), <String>{
        'curriculum_id',
        'sefaria_ref',
        'stage_id',
        'track_type',
        'source',
        'completed_at',
        'points',
      });
    });

    test('curriculum_id is written as the CurriculumId storageKey string', () {
      expect(base.toFirestore()['curriculum_id'], 'mishnayos');
    });

    test('source is written as the enum name string', () {
      expect(base.toFirestore()['source'], 'live');
    });
  });

  group('completed_at is a raw DateTime, NOT an ISO-8601 String — the '
      'completed_at <= request.time rules guard', () {
    test('toFirestore writes completed_at as a DateTime', () {
      final payload = base.toFirestore();
      expect(
        payload['completed_at'],
        isA<DateTime>(),
        reason:
            'firestore.rules compares completed_at <= request.time; a '
            'String value is type string in Firestore\'s eyes and a '
            'string-vs-timestamp comparison evaluates to deny, rejecting '
            'every recordCompletion call in production',
      );
    });

    test('the DateTime is normalised to UTC', () {
      final local = CompletionEntity(
        curriculumId: CurriculumId.chumash,
        sefariaRef: 'Bereishis 1:1',
        stageId: 1,
        trackType: 'personal',
        source: CompletionSource.live,
        completedAt: DateTime.utc(2026, 3, 3, 8),
      );

      final payload = local.toFirestore();
      expect((payload['completed_at'] as DateTime).isUtc, isTrue);
    });
  });

  group('no forbidden fields (AD-25/MCF-11)', () {
    test(
      'toFirestore never writes track_id, profile_id, or a Drift-style id',
      () {
        final payload = base.toFirestore();
        expect(payload, isNot(contains('track_id')));
        expect(payload, isNot(contains('profile_id')));
        expect(payload, isNot(contains('id')));
      },
    );
  });

  group('points defaults to 0 when omitted', () {
    test('a CompletionEntity built without points defaults to 0', () {
      final noPoints = CompletionEntity(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Berakhot 1:2',
        stageId: 1,
        trackType: 'personal',
        source: CompletionSource.live,
        completedAt: DateTime.utc(2026, 1, 1),
      );
      expect(noPoints.points, 0);
      expect(noPoints.toFirestore()['points'], 0);
    });
  });

  group('completionEntityFromFirestore — malformed input', () {
    Map<String, dynamic> validMap() => {
      'curriculum_id': 'mishnayos',
      'sefaria_ref': 'Berakhot 1:1',
      'stage_id': 2,
      'track_type': 'personal',
      'source': 'live',
      'completed_at': DateTime.utc(2026, 3, 1),
      'points': 10,
    };

    test('throws ArgumentError for an unrecognised curriculum_id', () {
      final data = validMap()..['curriculum_id'] = 'not-a-real-curriculum';
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when curriculum_id is missing entirely', () {
      final data = validMap()..remove('curriculum_id');
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for an unrecognised source', () {
      final data = validMap()..['source'] = 'not-a-real-source';
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException for source == lifetimeOnly — must never '
        'exist in this collection', () {
      final data = validMap()..['source'] = 'lifetimeOnly';
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when sefaria_ref is missing', () {
      final data = validMap()..remove('sefaria_ref');
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when stage_id is missing', () {
      final data = validMap()..remove('stage_id');
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when track_type is missing', () {
      final data = validMap()..remove('track_type');
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when completed_at is missing', () {
      final data = validMap()..remove('completed_at');
      expect(
        () => completionEntityFromFirestore(data),
        throwsA(isA<FormatException>()),
      );
    });

    test('points defaults to 0 when missing — documented fallback', () {
      final data = validMap()..remove('points');
      final decoded = completionEntityFromFirestore(data);
      expect(decoded.points, 0);
    });

    test('completed_at as a real Firestore Timestamp read-back (already a '
        'DateTime by the time it reaches this function) decodes correctly', () {
      final decoded = completionEntityFromFirestore(validMap());
      expect(decoded.completedAt, DateTime.utc(2026, 3, 1));
    });
  });
}
