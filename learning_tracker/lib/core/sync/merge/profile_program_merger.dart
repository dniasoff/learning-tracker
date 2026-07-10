/// LWW merger for profile-program association rows.
///
/// Natural key: `(profile_id, curriculum_id)` — one row per profile per
/// curriculum.
///
/// Phase 3: this merger consults [MergeStore.remoteIsNewer] using the
/// per-row `updated_at` (falling back to `tracking_start_date` when the
/// payload predates the new column) and persists the remote `updated_at`
/// after a successful apply so subsequent pulls arbitrate symmetrically.
library;

import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class ProfileProgramMerger implements EntityMerger {
  ProfileProgramMerger({
    required MergeStore store,
    AnalyticsService? analytics,
    AppLogger? logger,
  }) : _store = store,
       _analytics = analytics,
       _logger = logger;

  final MergeStore _store;
  // W7.5: optional analytics — fires merge_row_skipped for malformed rows.
  final AnalyticsService? _analytics;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = ProfileProgramCodec();

  @override
  String get kind => EntityKind.profileProgram;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        final decoded = _codec.decode(row);
        // Skip malformed rows — codec validates curriculum_id + program_id.
        if (decoded == null) {
          // W7.5: fire telemetry for every silently-skipped row.
          final future = _analytics?.logEvent(
            AnalyticsEvent.syncMergeRowSkipped,
            parameters: {
              'entity_kind': EntityKind.profileProgram,
              'reason': 'malformed_fields',
            },
          );
          if (future != null) unawaited(future);
          continue;
        }

        // LWW timestamp: prefer explicit `updated_at`, fall back to
        // `tracking_start_date` for older payloads.
        final remoteUpdatedAt = decoded.updatedAt ?? decoded.trackingStartDate;

        // R3-6: naturalKey is just curriculumId — profileId is added by
        // _scopedKey inside currentUpdatedAt/persistUpdatedAt, matching the
        // pattern used by TrackConfigMerger and every other LWW merger.
        // The previous '${decoded.profileId}|${decoded.curriculumId}' caused
        // double-scoping: stored key became '$profileId|$profileId|$curriculumId'.
        final naturalKey = decoded.curriculumId;
        final localUpdatedAt = await _store.currentUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
        );
        final localSyncedAt = await _store.currentSyncedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
        );
        // When the remote row carries no timestamp at all, this is a
        // legacy payload; treat it as "always wins on first sync" (the
        // existing local row is preserved if [remoteIsNewer] would otherwise
        // be false) by upserting only when no local timestamp is recorded.
        final shouldApply = remoteUpdatedAt == null
            ? localUpdatedAt == null
            : _store.remoteIsNewer(
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteUpdatedAt,
                localSyncedAt: localSyncedAt,
                remoteSyncedAt: decoded.syncedAt,
              );
        if (!shouldApply) continue;

        // AUD-core-sync-08: apply + persist the LWW shadow atomically — see
        // BookmarkMerger for the crash-mid-sequence rationale.
        await _store.runInTransaction(() async {
          await _store.upsert(kind: kind, profileId: profileId, fields: row);
          if (remoteUpdatedAt != null) {
            await _store.persistUpdatedAt(
              kind: kind,
              profileId: profileId,
              naturalKey: naturalKey,
              updatedAt: remoteUpdatedAt,
              syncedAt: decoded.syncedAt,
            );
          }
        });
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_profile_program_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
