import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/completion_events.dart';

/// Drift view over [CompletionEvents] that acts as the read-only replacement
/// for the old `completions` table (C1).
///
/// Returns every active (non-purged) completion event.  The `completions`
/// table remains in the schema for backward-compatibility with legacy rows but
/// is no longer written to after v20.
@DriftView(name: 'completions_view')
abstract class CompletionsView extends View {
  CompletionEvents get completionEvents;

  // drift_dev cannot parse a `..where()` cascade inside `as()` — it silently
  // produces an empty column list.  The WHERE purged_at IS NULL guard is
  // therefore applied via a manual CREATE VIEW statement in
  // UserDatabase.migration (see user_database.dart). This `as()` body exists
  // solely so drift_dev can extract the column types and generate
  // CompletionsViewData; it must NOT include a WHERE clause.
  @override
  // ignore: strict_raw_type
  Query as() => select([
    completionEvents.id,
    completionEvents.profileId,
    completionEvents.curriculumId,
    completionEvents.sefariaRef,
    completionEvents.stageId,
    completionEvents.trackType,
    completionEvents.trackId,
    completionEvents.points,
    completionEvents.eventTimestamp,
  ]).from(completionEvents);
}
