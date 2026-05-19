import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _CompletionCommand;
}
