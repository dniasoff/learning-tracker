/// Append-only merger for completion events.
///
/// Completions are events, not state — once written they are never updated
/// in place. The composite-UNIQUE invariant from DNI-323
/// (`profile_id, curriculum_id, sefaria_ref, completed_at`) guarantees that
/// a duplicate pull is a no-op. The natural key here is the firestore
/// document id (`firestore_id`), which is the only stable identifier the
/// server provides for a given event.
library;

import 'package:learning_tracker/core/ids/natural_key.dart';
import 'package:learning_tracker/core/sync/codec/completion_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class CompletionEventMerger implements EntityMerger {
  CompletionEventMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = CompletionEventCodec();

  @override
  String get kind => EntityKind.completion;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Malformed row — skip.

      final naturalKey = NaturalKey.forCompletion(
        firestoreId: decoded.firestoreId,
        profileId: profileId,
        curriculumId: decoded.curriculumId,
        sefariaRef: decoded.sefariaRef,
        completedAt: decoded.eventTimestamp.toIso8601String(),
      );
      await _store.insertIfAbsent(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey.value,
        fields: row,
      );
    }
  }
}
