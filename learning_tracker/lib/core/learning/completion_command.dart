import 'package:freezed_annotation/freezed_annotation.dart';

part 'completion_command.freezed.dart';

/// Identity + payload for a single completion write through [CompletionWriter].
///
/// All fields are required and non-nullable. The combination of
/// `(profileId, sefariaRef, stageId, trackType)` is the business key used for
/// idempotency: re-committing the same command returns the existing row and
/// does NOT enqueue a duplicate outbox push.
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
  }) = _CompletionCommand;
}
