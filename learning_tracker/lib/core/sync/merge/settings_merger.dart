import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

/// LWW merger for per-curriculum settings rows.
///
/// Natural key: `curriculum_id`. Remote wins iff its `updated_at` is
/// strictly newer than the local row.
class SettingsMerger implements EntityMerger {
  SettingsMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.settings;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final naturalKey = row['curriculum_id']?.toString() ?? '';
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      final remoteUpdatedAt = _parseUpdatedAt(row['updated_at']);
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }

  DateTime? _parseUpdatedAt(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
