import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';

/// Dispatches a page of rows from [PullPipeline] to the appropriate
/// [EntityMerger] by entity kind.
///
/// `MergeRouter implements MergeDispatcher`, so it slots directly into the
/// constructor of `PullPipeline`. The static map of mergers is the *only*
/// place outside [EntityKind] that enumerates the kind taxonomy — adding a
/// new entity is therefore a one-file addition plus one map entry.
class MergeRouter implements MergeDispatcher {
  MergeRouter({required Map<String, EntityMerger> mergers})
    : _mergers = mergers;

  final Map<String, EntityMerger> _mergers;

  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return MergeOutcome.continueNext;

    // The router's switch is expressed as a map lookup so adding a kind
    // costs exactly one map entry — no chain of `case` statements to grow.
    switch (kind) {
      case EntityKind.completion:
      case EntityKind.streak:
      case EntityKind.learnerProfile:
      case EntityKind.trackConfig:
      case EntityKind.bookmark:
      case EntityKind.settings:
      case EntityKind.stageDefinition:
        final merger = _mergers[kind];
        if (merger == null) {
          // Kind is recognised but no merger wired up — treat as a
          // configuration error rather than silently dropping the page.
          return MergeOutcome.halt;
        }
        await merger.merge(profileId: profileId, rows: rows);
        return MergeOutcome.continueNext;
      default:
        // Unknown kind — fail loudly so the pull loop stops and the
        // problem surfaces in logs rather than as silent data loss.
        return MergeOutcome.halt;
    }
  }
}
