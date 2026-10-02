/// A tutor's governed main-track writes (Story 1.24, DNI-486).
///
/// The tutor's goal / study-day / program forms reach the talmid's governed
/// docs only through the governed callables on [TutorWriteService] (Story
/// 1.10, plus `tutorReplaceStudyDays`) — the same `writeWithChangeLog` path
/// the owner's oversized writes use. Every action is ONE callable with ONE
/// client action id, so it is one server transaction: it carries its
/// `change_log` entry per entity and resolves last-writer-wins
/// per field by server commit order (AD-38, NFR-4). Each write first passes
/// the [TutorWritePreflight] (permission, online, the target learner's
/// lock); a refused preflight or a failed callable throws, so the form shows
/// its existing save error and nothing changes on screen.
library;

import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// A tutor governed write that did not happen: the preflight refused it
/// ([refusal]) or the callable failed ([failure]). Nothing was written.
final class TutorGovernedWriteException implements Exception {
  /// Creates the exception.
  const TutorGovernedWriteException({this.refusal, this.failure});

  /// The preflight outcome that refused the write, if any.
  final TutorPreflight? refusal;

  /// The callable failure, if any.
  final TutorWriteFailure? failure;

  @override
  String toString() =>
      'TutorGovernedWriteException(${refusal?.runtimeType ?? failure?.code})';
}

/// One study-day doc of a replaced schedule: its doc id and storage fields.
typedef TutorStudyDayDoc = ({String docId, Map<String, dynamic> data});

/// The governed main-track writes of one tutored [selection].
final class TutorGovernedWrites {
  /// Creates the writes.
  const TutorGovernedWrites({
    required TutoredProfileSelection selection,
    required TutorWriteService service,
    required TutorWritePreflight preflight,
    required UtcClock clock,
    required UlidSource newUlid,
  }) : _selection = selection,
       _service = service,
       _preflight = preflight,
       _clock = clock,
       _newUlid = newUlid;

  final TutoredProfileSelection _selection;
  final TutorWriteService _service;
  final TutorWritePreflight _preflight;
  final UtcClock _clock;
  final UlidSource _newUlid;

  /// Runs the one callable of a governed action after the preflight, with
  /// one client ULID as its action id (the server replays a repeated id).
  Future<void> _guarded(
    Future<TutorWriteResult> Function(String actionId) call,
  ) async {
    final check = await _preflight.check();
    if (check is! TutorPreflightPassed) {
      throw TutorGovernedWriteException(refusal: check);
    }
    final result = await call(_newUlid(_clock().toUtc()));
    if (result is TutorWriteFailure) {
      throw TutorGovernedWriteException(failure: result);
    }
  }

  /// Replaces [curriculumId]'s study days (`mainTrackStudyDays`): upserts
  /// [upserts] and tombstones [removedDocIds] in ONE `tutorReplaceStudyDays`
  /// call — one action id, one change_log entry for the entity, one server
  /// transaction — so a failure leaves the schedule exactly as it was.
  Future<void> replaceStudyDays({
    required String curriculumId,
    required List<TutorStudyDayDoc> upserts,
    List<String> removedDocIds = const [],
  }) async {
    if (upserts.isEmpty && removedDocIds.isEmpty) return;
    await _guarded(
      (actionId) => _service.replaceStudyDays(
        grantId: _selection.grantId,
        ownerUid: _selection.ownerUid,
        profileId: _selection.profileId,
        curriculumId: curriculumId,
        upserts: {for (final doc in upserts) doc.docId: doc.data},
        removedConfigIds: removedDocIds,
        actionId: actionId,
      ),
    );
  }

  /// Upserts the goal doc [goalId] (`goal`).
  Future<void> upsertGoal({
    required String goalId,
    required Map<String, dynamic> data,
  }) => _guarded(
    (actionId) => _service.upsertGoal(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      goalId: goalId,
      goalData: data,
      actionId: actionId,
    ),
  );

  /// Tombstones the goal doc [goalId] (`ended_at`, never a delete).
  Future<void> endGoal(String goalId) => _guarded(
    (actionId) => _service.deleteGoal(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      goalId: goalId,
      actionId: actionId,
    ),
  );

  /// Sets the profile program doc of [curriculumId] (`mainTrackProgram`).
  Future<void> setProfileProgram({
    required String curriculumId,
    required Map<String, dynamic> data,
  }) => _guarded(
    (actionId) => _service.setProfileProgram(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      programId: curriculumId,
      programData: data,
      actionId: actionId,
    ),
  );
}
