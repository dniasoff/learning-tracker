// MarkLiveCompletionUseCase — W4.34
//
// Enforces the canMarkLiveCompletion permission boundary before dispatching
// to the underlying completion machinery.
//
// This use case is the client-side enforcement layer. The server-side
// enforcement is in the Firestore rules (isOwner(uid) on completions) and
// in the Cloud Function (tutorBulkPriorCompletions) which rejects any
// completedAt that is not strictly in the past.
//
// Design: the use case is session-aware. It receives a [ResolvedSession] that
// identifies whether the caller is an owner or a tutor. Tutors are always
// rejected; owners are passed through to the delegate.

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// Delegate signature — the actual completion write implementation
/// (e.g. CompletionWriter.commit, MarkCompletionUseCase.call).
///
/// This avoids a hard dependency on the learning feature from the tutoring
/// feature (cross-feature deep imports are forbidden by coding standards).
typedef LiveCompletionDelegate<T> = Future<T> Function();

/// Use case that guards live completion writes by the caller's session role.
///
/// INVARIANT: A [SessionRole.tutor] session MUST NEVER result in a live
/// completion write to Firestore. This use case enforces that invariant.
///
/// Usage:
/// ```dart
/// final useCase = MarkLiveCompletionUseCase(session: resolvedSession);
/// final result = await useCase.call(
///   () => completionWriter.commit(command),
/// );
/// ```
class MarkLiveCompletionUseCase<T> {
  const MarkLiveCompletionUseCase({
    required this.session,
    AnalyticsService? analytics,
  }) : _analytics = analytics;

  final ResolvedSession session;
  // W7.11: optional analytics — fires tutor_live_mark_blocked when a tutor
  // session attempts a live completion write.
  final AnalyticsService? _analytics;

  /// Execute the live completion write for the current session.
  ///
  /// Throws [TutorWriteForbiddenException] if the session is a tutor session.
  /// Otherwise delegates to [writeDelegate] and returns its result.
  Future<T> call(LiveCompletionDelegate<T> writeDelegate) async {
    if (session.isTutorSession) {
      // The permissions VO always has canMarkLiveCompletion == false, but we
      // check the session role directly so the exception is thrown even if a
      // future bug inadvertently flips the permission field.
      // W7.11: fire analytics so tutor boundary violations are visible in
      // dashboards (in addition to the TutorWriteForbiddenException that
      // the UI layer catches for the friendly dialog).
      await _analytics?.logEvent(LogEvents.tutor.liveMarkBlocked);
      throw const TutorWriteForbiddenException();
    }
    return writeDelegate();
  }
}
