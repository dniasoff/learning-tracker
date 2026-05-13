import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Append-only merger for completion events.
///
/// Completions are events, not state — once written they are never updated
/// in place. The composite-UNIQUE invariant from DNI-323
/// (`profile_id, curriculum_id, sefaria_ref, completed_at`) guarantees that
/// a duplicate pull is a no-op. The natural key here is the firestore
/// document id (`firestore_id`), which is the only stable identifier the
/// server provides for a given event.
class CompletionEventMerger implements EntityMerger {
  CompletionEventMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.completion;

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
      '$profileId|${row['curriculum_id']}|${row['sefaria_ref']}|'
      '${row['completed_at']}';
}
