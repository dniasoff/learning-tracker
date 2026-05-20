/// LWW merger for profile-program association rows.
///
/// Natural key: `(profile_id, curriculum_id)` — one row per profile per
/// curriculum. Remote always wins (last-write-wins on `tracking_start_date`
/// is fine; `program_id` and `tracking_start_date` are only ever set via
/// the setup / onboarding flow, so the most-recent write is canonical).
library;

import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class ProfileProgramMerger implements EntityMerger {
  ProfileProgramMerger({required MergeStore store, AnalyticsService? analytics})
    : _store = store,
      _analytics = analytics;

  final MergeStore _store;
  // W7.5: optional analytics — fires merge_row_skipped for malformed rows.
  final AnalyticsService? _analytics;
  static const _codec = ProfileProgramCodec();

  @override
  String get kind => EntityKind.profileProgram;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      // Skip malformed rows — codec validates curriculum_id + program_id.
      if (decoded == null) {
        // W7.5: fire telemetry for every silently-skipped row.
        final future = _analytics?.logEvent(
          LogEvents.sync.mergeRowSkipped,
          parameters: {
            'entity_kind': EntityKind.profileProgram,
            'reason': 'malformed_fields',
          },
        );
        if (future != null) unawaited(future);
        continue;
      }

      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
