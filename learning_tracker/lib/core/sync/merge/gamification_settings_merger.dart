import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback used by [GamificationSettingsMerger] to merge the
/// `reward_settings` sub-map. The implementation lives in
/// `features/gamification/` to avoid a core→features import violation.
///
/// Receives the raw JSON sub-map and the active [profileId].
typedef RewardSettingsMergeDelegate =
    Future<void> Function(Map<String, dynamic>? remote, int profileId);

/// LWW merger for the `gamification_settings/config` Firestore document
/// (W2.27 / closes M1).
///
/// Gamification settings are stored as a single Firestore document. The row
/// passed to [merge] is a synthetic single-element list (see
/// [PullPipeline.pullDocument]). The merge touches two stores:
///   * Drift — [PointConfigsCompanion] rows via [UserDatabase.pointConfigDao].
///   * SharedPreferences — the LWW timestamp + reward_settings delegation.
///
/// Reward milestones logic lives in [RewardMilestoneService] (features layer).
/// Rather than importing that class here (which would break the core→features
/// rule), the caller injects a [RewardSettingsMergeDelegate] callback.
///
/// Firestore shape (from SyncEngine._mergeGamificationSettings):
///   updated_at, points_config[]{profile_id,track_id,curriculum_id,
///   stage_order,points}, reward_settings, lifetime_stats.
///
/// Phase 3: the merger consults [MergeStore.remoteIsNewer] (which knows
/// about clock-skew arbitration), and after a successful apply calls
/// [MergeStore.persistUpdatedAt] so the persisted LWW timestamp survives
/// SharedPreferences resets. The SharedPreferences key is kept up to date
/// in parallel because [RewardMilestoneService] reads it directly.
class GamificationSettingsMerger implements EntityMerger {
  const GamificationSettingsMerger({
    required UserDatabase db,
    required MergeStore store,
    RewardSettingsMergeDelegate? onRewardSettings,
    AppLogger? logger,
  }) : _db = db,
       _store = store,
       _onRewardSettings = onRewardSettings,
       _logger = logger;

  final UserDatabase _db;
  final MergeStore _store;
  final RewardSettingsMergeDelegate? _onRewardSettings;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;

  static String _timestampKey(int profileId) =>
      'gamification_settings_updated_at_ms_p$profileId';

  /// Single natural key — gamification settings are a per-profile singleton.
  static const _naturalKey = 'config';

  @override
  String get kind => EntityKind.gamificationSettings;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return;
    final remote = rows.first;
    if (remote.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
    final remoteSyncedAt = _parseTimestamp(remote['synced_at']);
    var localUpdatedAt = await _store.currentUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
    );
    if (localUpdatedAt == null) {
      final localMs = prefs.getInt(_timestampKey(profileId));
      if (localMs != null) {
        localUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
          localMs,
          isUtc: true,
        );
      }
    }
    final localSyncedAt = await _store.currentSyncedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
    );

    if (!_store.remoteIsNewer(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      localSyncedAt: localSyncedAt,
      remoteSyncedAt: remoteSyncedAt,
    )) {
      return;
    }

    // Merge points_config rows into Drift.
    final remoteRows = remote['points_config'];
    if (remoteRows is List) {
      for (final raw in remoteRows) {
        // AUD-core-sync-15: isolate each points_config sub-row — a single
        // malformed/throwing entry must not drop the rest of the document's
        // point configuration.
        try {
          if (raw is! Map) continue;
          final map = raw.map((k, v) => MapEntry(k.toString(), v));
          final curriculumId = map['curriculum_id'] as String?;
          final stageOrder = (map['stage_order'] as num?)?.toInt();
          final points = (map['points'] as num?)?.toInt();
          final remoteTrackId = (map['track_id'] as num?)?.toInt();
          if (curriculumId == null ||
              stageOrder == null ||
              points == null ||
              remoteTrackId == null) {
            continue;
          }

          // Bug 3: point_configs.trackId FKs into curriculum_tracks. The stored
          // track_id is the REMOTE id; under a tutored mirror the track was
          // re-inserted with a different local autoincrement id, so inserting the
          // remote id throws a FK violation (this is the tutored_pull_error /
          // tutored_listener_merge_error for gamification_settings). Resolve the
          // LOCAL track by (profile, curriculum); skip the row when no local
          // track exists yet (it re-merges on the next pull). No-op for own-data.
          final localTrack = await _db.trackDao.getTrackByProfileAndCurriculum(
            profileId,
            curriculumId,
          );
          if (localTrack == null) continue;

          await _db.pointConfigDao.upsertConfig(
            PointConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              trackId: localTrack.id,
              stageOrder: stageOrder,
              points: points,
            ),
          );
        } on Exception catch (e, stackTrace) {
          _logger?.warning(
            event: 'sync_gamification_settings_merge_row_failed',
            fields: {'profile_id': profileId},
            exception: e,
            stackTrace: stackTrace,
          );
        }
      }
    }

    // Delegate reward_settings merge to the features-layer callback.
    final rewardSettingsRaw = remote['reward_settings'];
    if (_onRewardSettings != null) {
      final rewardMap = rewardSettingsRaw is Map
          ? rewardSettingsRaw.map((k, v) => MapEntry(k.toString(), v))
          : null;
      await _onRewardSettings(rewardMap, profileId);
    }

    final stamp = remoteUpdatedAt ?? DateTimeFactory.nowUtc();
    await prefs.setInt(_timestampKey(profileId), stamp.millisecondsSinceEpoch);
    await _store.persistUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
      updatedAt: stamp,
      syncedAt: remoteSyncedAt,
    );
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
