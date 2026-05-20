import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';
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
class GamificationSettingsMerger implements EntityMerger {
  const GamificationSettingsMerger({
    required UserDatabase db,
    RewardSettingsMergeDelegate? onRewardSettings,
  }) : _db = db,
       _onRewardSettings = onRewardSettings;

  final UserDatabase _db;
  final RewardSettingsMergeDelegate? _onRewardSettings;

  static String _timestampKey(int profileId) =>
      'gamification_settings_updated_at_ms_p$profileId';

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
    final localMs = prefs.getInt(_timestampKey(profileId));
    final localUpdatedAt = localMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(localMs, isUtc: true);

    if (!remoteIsNewer(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
    )) {
      return;
    }

    // Merge points_config rows into Drift.
    final remoteRows = remote['points_config'];
    if (remoteRows is List) {
      for (final raw in remoteRows) {
        if (raw is! Map) continue;
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final curriculumId = map['curriculum_id'] as String?;
        final stageOrder = (map['stage_order'] as num?)?.toInt();
        final points = (map['points'] as num?)?.toInt();
        final trackId = (map['track_id'] as num?)?.toInt();
        if (curriculumId == null ||
            stageOrder == null ||
            points == null ||
            trackId == null) {
          continue;
        }

        await _db.pointConfigDao.upsertConfig(
          PointConfigsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: stageOrder,
            points: points,
          ),
        );
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

    final stamp =
        remoteUpdatedAt?.millisecondsSinceEpoch ??
        DateTimeFactory.nowUtc().millisecondsSinceEpoch;
    await prefs.setInt(_timestampKey(profileId), stamp);
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
