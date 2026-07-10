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
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/completion_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class CompletionEventMerger implements EntityMerger {
  CompletionEventMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = CompletionEventCodec();

  @override
  String get kind => EntityKind.completion;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
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
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_completion_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
