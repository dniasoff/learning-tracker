/// Unit tests for [GoalCodec]: encode<->decode round-trip, required-field
/// null-guards, the pace_unit/pace_period/paceUnit alias fallback chain,
/// and the target_percent/date_type/goal_type camelCase legacy fallbacks.
///
/// AG-5 (AUD-app-05): new file — the codec's payload shape was previously
/// exercised only indirectly through
/// test/core/sync/merge/goal_merger_test.dart's DB round-trip (kept there
/// for merge-behaviour coverage); this file adds the codec-only unit
/// coverage AG-5 requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/goal_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

void main() {
  const codec = GoalCodec();
  final createdAt = DateTime.utc(2026, 1, 1);
  final updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);

  GoalRow row({
    String firestoreId = 'g1',
    int profileId = 1,
    String curriculumId = 'bavli',
    int? trackId,
    double targetPercent = 100.0,
    String description = 'Finish',
    String dateType = 'gregorian',
    String goalType = 'deadline',
    int? paceValue,
    String? pacePeriod,
    String? paceGranularity,
    DateTime? targetDate,
  }) => GoalRow(
    firestoreId: firestoreId,
    profileId: profileId,
    curriculumId: curriculumId,
    updatedAt: updatedAt,
    createdAt: createdAt,
    trackId: trackId,
    targetPercent: targetPercent,
    description: description,
    dateType: dateType,
    goalType: goalType,
    paceValue: paceValue,
    pacePeriod: pacePeriod,
    paceGranularity: paceGranularity,
    targetDate: targetDate,
  );

  group('GoalCodec — kind', () {
    test('kind is "goal"', () {
      expect(codec.kind, EntityKind.goal);
    });
  });

  group('GoalCodec — encode', () {
    test('emits pace value under the rule-legal pace_unit key', () {
      final payload = codec.encode(row(pacePeriod: 'per_day'));
      expect(payload['pace_unit'], 'per_day');
      expect(payload.containsKey('pace_period'), isFalse);
    });

    test('track_id, pace fields and target_date are omitted when null', () {
      final payload = codec.encode(row());
      expect(payload.containsKey('track_id'), isFalse);
      expect(payload.containsKey('pace_value'), isFalse);
      expect(payload.containsKey('pace_unit'), isFalse);
      expect(payload.containsKey('pace_granularity'), isFalse);
      expect(payload.containsKey('target_date'), isFalse);
    });

    test('does not include the firestore_id (injected post-encode)', () {
      expect(codec.encode(row()).containsKey('firestore_id'), isFalse);
    });
  });

  group('GoalCodec — decode required fields (returns null when missing)', () {
    final validRaw = {
      'firestore_id': 'g1',
      'profile_id': 1,
      'curriculum_id': 'bavli',
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };

    test('valid input decodes', () {
      expect(codec.decode(validRaw), isNotNull);
    });

    test('missing firestore_id', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('firestore_id');
      expect(codec.decode(raw), isNull);
    });

    test('missing profile_id', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('profile_id');
      expect(codec.decode(raw), isNull);
    });

    test('missing curriculum_id', () {
      final raw = Map<String, dynamic>.from(validRaw)..remove('curriculum_id');
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
  });

  group('GoalCodec — pace_unit read-fallback chain', () {
    Map<String, dynamic> raw({String? key, String? value}) => {
      'firestore_id': 'g1',
      'profile_id': 1,
      'curriculum_id': 'bavli',
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (key != null) key: value,
    };

    test('canonical pace_unit is read', () {
      expect(
        codec.decode(raw(key: 'pace_unit', value: 'per_week'))?.pacePeriod,
        'per_week',
      );
    });

    test('legacy pace_period is a fallback', () {
      expect(
        codec.decode(raw(key: 'pace_period', value: 'per_week'))?.pacePeriod,
        'per_week',
      );
    });

    test('legacy camelCase pacePeriod is a fallback', () {
      expect(
        codec.decode(raw(key: 'pacePeriod', value: 'per_week'))?.pacePeriod,
        'per_week',
      );
    });
  });

  group('GoalCodec — defaults', () {
    final minimal = {
      'firestore_id': 'g1',
      'profile_id': 1,
      'curriculum_id': 'bavli',
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };

    test('target_percent defaults to 100.0', () {
      expect(codec.decode(minimal)?.targetPercent, 100.0);
    });

    test('description defaults to empty string', () {
      expect(codec.decode(minimal)?.description, '');
    });

    test('date_type defaults to gregorian', () {
      expect(codec.decode(minimal)?.dateType, 'gregorian');
    });

    test('goal_type defaults to deadline', () {
      expect(codec.decode(minimal)?.goalType, 'deadline');
    });
  });
}
