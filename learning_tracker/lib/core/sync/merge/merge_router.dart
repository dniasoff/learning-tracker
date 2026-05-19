import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';

/// Dispatches a page of rows from [PullPipeline] to the appropriate
/// [EntityMerger] by entity kind.
///
/// `MergeRouter implements MergeDispatcher`, so it slots directly into the
/// constructor of `PullPipeline`. Adding a new entity kind requires exactly
/// three touches in this file: one `EntityKind` constant, one `case` label in
/// the exhaustiveness switch below, and one entry in the `mergers` map. No
/// other production file enumerates the full kind set.
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

    // All valid kinds fall through to the map lookup. The exhaustiveness
    // switch ensures the default halt fires for unknown kinds, and that
    // adding a kind requires a new case label here (plus a map entry).
    switch (kind) {
      case EntityKind.completion:
      case EntityKind.streak:
      case EntityKind.learnerProfile:
      case EntityKind.trackConfig:
      case EntityKind.bookmark:
      case EntityKind.settings:
      case EntityKind.stageDefinition:
      case EntityKind.profileProgram:
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
