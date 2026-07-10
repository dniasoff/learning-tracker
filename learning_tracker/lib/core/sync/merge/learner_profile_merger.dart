/// LWW merger for learner profile rows.
///
/// Natural key: `profile_id` (the profile is identifying itself). Remote
/// wins iff its `updated_at` is strictly newer than the local row; within
/// ±5 s clock skew the Firestore server timestamp (`synced_at`) decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class LearnerProfileMerger implements EntityMerger {
  LearnerProfileMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // Bug 1: optional logger so a per-row merge failure is observable instead of
  // silently swallowed.
  final AppLogger? _logger;
  static const _codec = LearnerProfileCodec();

  @override
  String get kind => EntityKind.learnerProfile;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // Bug 1: isolate each row. A single malformed/FK-violating profile row
      // must never abort the whole page (and, upstream, the whole launch pull
      // that bounces the user to the splash). Catch, log, and move on.
      try {
        final decoded = _codec.decode(row);
        // Fall back to caller's profileId when profile_id is absent.
        final naturalKey = decoded != null
            ? decoded.profileId.toString()
            : profileId.toString();

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
        final remoteUpdatedAt = decoded?.updatedAt;
        if (!_store.remoteIsNewer(
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
          localSyncedAt: localSyncedAt,
          remoteSyncedAt: decoded?.syncedAt,
        )) {
          continue;
        }
        // AUD-core-sync-08: apply + persist the LWW shadow atomically — see
        // BookmarkMerger for the crash-mid-sequence rationale. Stays inside
        // this row's try/catch so a rollback (or a throw from either write)
        // is still caught and logged per-row (Bug 1), not just per-page.
        await _store.runInTransaction(() async {
          await _store.upsert(kind: kind, profileId: profileId, fields: row);
          if (remoteUpdatedAt != null) {
            await _store.persistUpdatedAt(
              kind: kind,
              profileId: profileId,
              naturalKey: naturalKey,
              updatedAt: remoteUpdatedAt,
              syncedAt: decoded?.syncedAt,
            );
          }
        });
      } on Exception catch (e, stackTrace) {
        // AUD-core-sync-25 (EH-4): typed `on Exception` — a bare catch also
        // traps Error subtypes (TypeError, RangeError, AssertionError),
        // masking real programming bugs behind a quiet warning log instead
        // of a loud dev/QA crash. Genuine Errors now propagate.
        _logger?.warning(
          event: 'sync_learner_profile_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
