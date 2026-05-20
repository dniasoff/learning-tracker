// W3.17 / W3.38 — TutorGrantMerger (S2 sync stream, closes T17)
//
// Tutor grants are stored exclusively in Firestore (no local SQLite row).
// The pull pipeline routes tutor_grant pages through this merger; the merger
// is a deliberate no-op at the DB layer — live-query code reads grants from
// Firestore directly via [TutorGrantRepository].
//
// Keeping a wired merger (rather than halting on the kind) means the pull
// pipeline returns [MergeOutcome.continueNext] and paginates normally, which
// prevents future grant pages from being silently dropped.
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// No-op merger for `tutor_grants` Firestore documents.
///
/// Tutor grants are not stored in the local SQLite database; they are always
/// read live from Firestore. This merger exists so that the [MergeRouter]
/// can return [MergeOutcome.continueNext] for the `tutor_grant` kind instead
/// of halting the pull pipeline.
class TutorGrantMerger implements EntityMerger {
  const TutorGrantMerger();

  @override
  String get kind => EntityKind.tutorGrant;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    // No local storage — tutor grants are Firestore-live. No-op.
  }
}
