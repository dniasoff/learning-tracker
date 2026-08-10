/// Unit tests for [TutorGrantCodec]: encode<->decode round-trip and
/// required-field null-guards.
///
/// AG-5 (AUD-app-05): new file — no prior mirrored or unmirrored test
/// existed for this codec (tutor_grants sync through the no-op
/// [TutorGrantMerger] — see test/core/sync/merge/tutor_grant_merger_test.dart
/// — and are otherwise read live from Firestore, so this codec's own
/// encode()/decode() shape had zero direct coverage before now).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/tutor_grant_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = TutorGrantCodec();
  final createdAt = DateTime.utc(2026, 1, 1);
  final updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  TutorGrantRow row({String? tutorEmail, DateTime? revokedAt}) => TutorGrantRow(
    grantId: 'g1',
    tutorUid: 'tutor-1',
    parentUid: 'parent-1',
    childProfileId: 3,
    state: 'active',
    createdAt: createdAt,
    updatedAt: updatedAt,
    tutorEmail: tutorEmail,
    revokedAt: revokedAt,
  );

  group('TutorGrantCodec — kind', () {
    test('kind is "tutor_grant"', () {
      expect(codec.kind, EntityKind.tutorGrant);
    });
  });

  group('TutorGrantCodec — encode → decode round-trip', () {
    test('round-trips required fields', () {
      final decoded = codec.decode(codec.encode(row()));
      expect(decoded, isNotNull);
      expect(decoded!.grantId, 'g1');
      expect(decoded.tutorUid, 'tutor-1');
      expect(decoded.parentUid, 'parent-1');
      expect(decoded.childProfileId, 3);
      expect(decoded.state, 'active');
      expect(decoded.createdAt, createdAt);
      expect(decoded.updatedAt, updatedAt);
    });

    test('tutorEmail is omitted from encode() output when null', () {
      expect(codec.encode(row()).containsKey('tutor_email'), isFalse);
    });

    test('tutorEmail round-trips when present', () {
      final decoded = codec.decode(
        codec.encode(row(tutorEmail: 'tutor@example.com')),
      );
      expect(decoded?.tutorEmail, 'tutor@example.com');
    });

    test('revokedAt is omitted from encode() output when null', () {
      expect(codec.encode(row()).containsKey('revoked_at'), isFalse);
    });

    test('revokedAt round-trips when present', () {
      final revokedAt = DateTime.utc(2026, 7, 1);
      final decoded = codec.decode(codec.encode(row(revokedAt: revokedAt)));
      expect(decoded?.revokedAt, revokedAt);
    });
  });

  group('TutorGrantCodec — decode returns null for malformed inputs', () {
    final validRaw = {
      'grant_id': 'g1',
      'tutor_uid': 'tutor-1',
      'parent_uid': 'parent-1',
      'child_profile_id': 3,
      'state': 'active',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    test('valid input decodes', () {
      expect(codec.decode(validRaw), isNotNull);
    });

    for (final key in [
      'grant_id',
      'tutor_uid',
      'parent_uid',
      'child_profile_id',
      'state',
      'created_at',
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
