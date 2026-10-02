/// Port for the reads a governed write makes before it writes (AD-38): the
/// writer's view of a governed doc (its `before` baseline, the undo
/// "still equals `after`" test and the create-undo `last_change_id` check)
/// and one change-log entry by id (who changed a field since).
///
/// Filled by DNI-470 (1.8) in
/// `lib/data/repositories/firestore_change_log_repository.dart`. Additive
/// to the C0 (DNI-524) surface.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// Reads governed docs and change-log entries one at a time.
abstract interface class GovernedDocReader {
  /// The writer's view of `{collection}/{docId}` under [scope] (local
  /// cache, then server), storage form with timestamps as UTC `DateTime`s;
  /// null when the doc is absent, or unknown to an offline client.
  ///
  /// AD-38: an owner-path entry's `before` is this cached value per field,
  /// `null` when absent. A read failure other than "offline" throws.
  Future<Map<String, Object?>?> currentDoc(
    LearnerScope scope,
    String collection,
    String docId,
  );

  /// `change_log/{entryId}` under [scope], or null when it cannot be found
  /// or decoded.
  Future<ChangeLogEntry?> entry(LearnerScope scope, String entryId);
}
