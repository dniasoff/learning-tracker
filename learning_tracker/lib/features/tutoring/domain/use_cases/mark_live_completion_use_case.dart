// MarkLiveCompletionUseCase — W4.34, rerouted by Story 1.24 (DNI-486)
//
// Routes a live completion (the reader's Mark complete) by the caller's
// session role:
//
//   * owner (parent / child) → the owner capture, `LearningCommands.capture`
//     (Story 1.11, DNI-473), unchanged;
//   * tutor → the tutor capture, `TutorLearningCommands.capture`, whose only
//     write is `TutorWriteService.recordLearning` → the Story 1.23
//     `tutorRecordLearning` callable (AD-53, deviation #7: a tutor with
//     `can_edit_learning` may record learning).
//
// Design: the use case is session-aware. It receives a [ResolvedSession] that
// identifies whether the caller is an owner or a tutor. Tutors are always
// rejected; owners are passed through to the delegate.
//
// Story 1.11 (DNI-473, AC-6): the owner delegate is the owner capture,
// `LearningCommands.capture` (the reader's Mark complete). The tutor branch
// below is unchanged until the tutor-capture story reroutes it to
// `TutorWriteService`.

import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// Delegate signature — the actual owner write: `LearningCommands.capture`
/// (Story 1.11, DNI-473).
///
/// This avoids a hard dependency on the learning feature from the tutoring
/// feature domain (cross-feature deep imports are forbidden by coding
/// standards).
typedef LiveCompletionDelegate<T> = Future<T> Function();

/// Use case that routes a live completion write by the caller's session
/// role.
///
/// INVARIANT: a [SessionRole.tutor] session never reaches the owner write
/// (a client Firestore batch the tutor's rules would deny, AD-46): it runs
/// only the tutor write, which is a callable.
///
/// Usage:
/// ```dart
/// final useCase = MarkLiveCompletionUseCase<CaptureResult>(
///   session: resolvedSession,
/// );
/// final result = await useCase.call(
///   () => commands.capture(curriculumId: id, refs: refs, ...),
/// );
/// ```
class MarkLiveCompletionUseCase<T> {
  const MarkLiveCompletionUseCase({required this.session});

  final ResolvedSession session;

  /// Runs [tutorWrite] for a tutor session and [ownerWrite] otherwise, and
  /// returns its result.
  Future<T> call(
    LiveCompletionDelegate<T> ownerWrite, {
    required LiveCompletionDelegate<T> tutorWrite,
  }) => session.isTutorSession ? tutorWrite() : ownerWrite();
}
