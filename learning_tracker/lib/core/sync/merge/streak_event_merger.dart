import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Append-only merger for streak events.
///
/// Streak state is derived by replaying the event log (DNI-337 — `core/streak/`
/// reducer). Merging a pull therefore means inserting any unseen events;
/// the reducer rebuilds the snapshot on the next read. Duplicates are
/// dropped by the composite-UNIQUE constraint introduced in DNI-323.
class StreakEventMerger implements EntityMerger {
  StreakEventMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.streak;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final naturalKey =
          row['firestore_id']?.toString() ?? _eventKey(row, profileId);
      await _store.insertIfAbsent(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
        fields: row,
      );
    }
  }

  String _eventKey(Map<String, dynamic> row, int profileId) =>
      '$profileId|${row['event_type']}|${row['occurred_at']}';
}
