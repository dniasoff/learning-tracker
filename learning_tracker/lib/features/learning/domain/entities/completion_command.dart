import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

part 'completion_command.freezed.dart';

/// Identity + payload for a single completion write through [CompletionWriter].
///
/// All fields are required and non-nullable. The combination of
/// `(profileId, sefariaRef, stageId, trackType)` is the business key used for
/// idempotency: re-committing the same command returns the existing row and
/// does NOT enqueue a duplicate outbox push.
///
/// [priorMarkOnly] is `true` when this command originates from the bulk-prior-
/// marking flow (onboarding "I learned this before"). [CompletionWriter] sets
/// `prior_mark_only = 1` on the inserted row. When a real-learning [commit]
/// hits an existing row with `prior_mark_only = 1` it upgrades the row
/// (clears the flag, updates `eventTimestamp`) so the item survives a
/// subsequent [BulkPriorCompletionService.expungePriorCompletions] call.
///
/// [source] is the B1 three-tier credit provenance of this command. It is the
/// single source of truth the writer uses to stamp `prior_completion_imports
/// .source`, so a [CompletionSource.lifetimeOnly] command is persisted as
/// `'lifetimeOnly'` (NOT mis-tagged as `'bulkInTrack'`), keeping it out of the
/// trackAchievement tier. For `priorMarkOnly = true` commands this MUST be
/// either [CompletionSource.bulkInTrack] or [CompletionSource.lifetimeOnly];
/// the default [CompletionSource.live] preserves the live-write semantics for
/// every existing caller that does not set it.
@freezed
abstract class CompletionCommand with _$CompletionCommand {
  const factory CompletionCommand({
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required int trackId,
    required DateTime completedAt,
    required int points,
    @Default(false) bool priorMarkOnly,
    @Default(CompletionSource.live) CompletionSource source,
  }) = _CompletionCommand;
}
