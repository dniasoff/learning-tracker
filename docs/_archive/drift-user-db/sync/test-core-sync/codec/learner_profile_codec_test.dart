/// Unit tests for [LearnerProfileCodec]: encode<->decode round-trip and
/// required-field null-guards.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/learner_profile_merger_test.dart's DB round-trip
/// (kept there for merge-behaviour coverage); this file adds the
/// codec-only unit coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = LearnerProfileCodec();
  final createdAt = DateTime.utc(2026, 1, 1);
  final updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  LearnerProfileRow row({
    int profileId = 42,
    int accountId = 1,
    String displayName = 'Alice',
    String mode = 'adult',
    int avatarIndex = 3,
    DateTime? syncedAt,
  }) => LearnerProfileRow(
    profileId: profileId,
    accountId: accountId,
    displayName: displayName,
    mode: mode,
    updatedAt: updatedAt,
    createdAt: createdAt,
    avatarIndex: avatarIndex,
    syncedAt: syncedAt,
  );

  group('LearnerProfileCodec — kind', () {
    test('kind is "learner_profile"', () {
      expect(codec.kind, EntityKind.learnerProfile);
    });
  });

  group('LearnerProfileCodec — encode → decode round-trip', () {
    test('round-trips all fields', () {
      final decoded = codec.decode(codec.encode(row()));
      expect(decoded, isNotNull);
      expect(decoded!.profileId, 42);
      expect(decoded.accountId, 1);
      expect(decoded.displayName, 'Alice');
      expect(decoded.mode, 'adult');
      expect(decoded.avatarIndex, 3);
      expect(decoded.updatedAt, updatedAt);
      expect(decoded.createdAt, createdAt);
    });

    test('encode() never emits synced_at (server-only field)', () {
      final syncedAt = DateTime.utc(2026, 6, 18, 10, 0, 5);
      final payload = codec.encode(row(syncedAt: syncedAt));
      expect(payload.containsKey('synced_at'), isFalse);
    });
  });

  group('LearnerProfileCodec — decode returns null for malformed inputs', () {
    final validRaw = {
      'profile_id': 1,
      'account_id': 1,
      'display_name': 'Alice',
      'mode': 'adult',
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };

    test('valid input decodes', () {
      expect(codec.decode(validRaw), isNotNull);
    });

    test('missing profile_id', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('profile_id');
      expect(codec.decode(raw), isNull);
    });

    test('missing account_id', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('account_id');
      expect(codec.decode(raw), isNull);
    });

    test('missing display_name', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('display_name');
      expect(codec.decode(raw), isNull);
    });

    test('missing mode', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('mode');
      expect(codec.decode(raw), isNull);
    });

    test('missing updated_at', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('updated_at');
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

  group('LearnerProfileCodec — defaults', () {
    test('missing avatar_index defaults to 0', () {
      final decoded = codec.decode({
        'profile_id': 1,
        'account_id': 1,
        'display_name': 'Alice',
        'mode': 'adult',
        'updated_at': updatedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      });
      expect(decoded?.avatarIndex, 0);
    });
  });
}
