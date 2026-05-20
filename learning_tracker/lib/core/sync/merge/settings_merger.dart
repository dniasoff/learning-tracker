/// LWW merger for per-curriculum settings rows.
///
/// Natural key: `curriculum_id`. Remote wins iff its `updated_at` is
/// strictly newer than the local row.
library;

import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

class SettingsMerger implements EntityMerger {
  SettingsMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = SettingsCodec();

  @override
  String get kind => EntityKind.settings;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Missing curriculumId — skip.

      final naturalKey = decoded.curriculumId;
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: decoded.updatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
