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
///
/// **Frozen action ids (AD-31 / AD-38 idempotency, AC-5).** An action's id
/// is allocated and frozen in the [TutorGovernedActionLedger] BEFORE its
/// callable runs, keyed by the action's request (operation, target and
/// payload, without the volatile `updated_at` / `synced_at` stamps). It is
/// released only on a definitive receipt: success, or a non-retryable
/// rejection (nothing was written). After a retryable failure (a timeout
/// whose commit may have landed, no network) the id stays frozen, so the
/// tutor's retry of the same save re-sends the SAME id and the server
/// replays a committed action instead of writing a second change_log entry.
/// A multi-entity form save (track edit: study days, goal) is therefore
/// retryable as a whole: each already-committed action replays.
library;

import 'dart:convert';

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

/// The frozen action ids of governed tutor actions whose outcome is not
/// yet known (a retryable failure), keyed by the action's request
/// fingerprint. Lives as long as the app session, so a retry from a
/// re-opened form still reuses the id.
final class TutorGovernedActionLedger {
  final Map<String, String> _frozen = {};

  /// The frozen id of [fingerprint], freezing [mint]'s id on first use.
  String reserve(String fingerprint, String Function() mint) =>
      _frozen.putIfAbsent(fingerprint, mint);

  /// Releases [fingerprint] after a definitive receipt.
  void release(String fingerprint) => _frozen.remove(fingerprint);

  /// Whether an action id is frozen for [fingerprint] (tests).
  bool isFrozen(String fingerprint) => _frozen.containsKey(fingerprint);

  /// The number of frozen actions.
  int get length => _frozen.length;
}

/// Stamp fields rewritten on every attempt; they do not identify an action.
const _volatileKeys = {'updated_at', 'synced_at'};

Object? _canonical(Object? value) => switch (value) {
  final Map<dynamic, dynamic> map => {
    for (final key in (map.keys.map((k) => '$k').toList()..sort()))
      if (!_volatileKeys.contains(key)) key: _canonical(map[key]),
  },
  final Iterable<dynamic> list => [for (final v in list) _canonical(v)],
  final DateTime d => d.toUtc().toIso8601String(),
  _ => value,
};

/// The fingerprint of one governed [operation] with [request]: canonical
/// JSON (sorted keys, volatile stamps dropped).
String tutorGovernedActionFingerprint(
  String operation,
  Map<String, Object?> request,
) => jsonEncode([operation, _canonical(request)], toEncodable: (o) => '$o');

/// The governed main-track writes of one tutored [selection].
final class TutorGovernedWrites {
  /// Creates the writes. [ledger] holds the frozen action ids; pass the
  /// session-wide one so retries survive a rebuilt instance.
  TutorGovernedWrites({
    required TutoredProfileSelection selection,
    required TutorWriteService service,
    required TutorWritePreflight preflight,
    required UtcClock clock,
    required UlidSource newUlid,
    TutorGovernedActionLedger? ledger,
  }) : _selection = selection,
       _service = service,
       _preflight = preflight,
       _clock = clock,
       _newUlid = newUlid,
       _ledger = ledger ?? TutorGovernedActionLedger();

  final TutoredProfileSelection _selection;
  final TutorWriteService _service;
  final TutorWritePreflight _preflight;
  final UtcClock _clock;
  final UlidSource _newUlid;
  final TutorGovernedActionLedger _ledger;

  /// Runs the one callable of a governed action after the preflight. The
  /// action id is frozen for [operation] + [request] before the call and
  /// reused by every retry until a definitive receipt (see library doc).
  Future<void> _guarded(
    String operation,
    Map<String, Object?> request,
    Future<TutorWriteResult> Function(String actionId) call,
  ) async {
    final check = await _preflight.check();
    if (check is! TutorPreflightPassed) {
      throw TutorGovernedWriteException(refusal: check);
    }
    final fingerprint = tutorGovernedActionFingerprint(operation, {
      'grantId': _selection.grantId,
      'ownerUid': _selection.ownerUid,
      'profileId': _selection.profileId,
      ...request,
    });
    final actionId = _ledger.reserve(
      fingerprint,
      () => _newUlid(_clock().toUtc()),
    );
    // A throw here leaves the outcome unknown: the id stays frozen.
    final result = await call(actionId);
    if (result is TutorWriteFailure) {
      if (!result.isRetryable) _ledger.release(fingerprint);
      throw TutorGovernedWriteException(failure: result);
    }
    _ledger.release(fingerprint);
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
      'replaceStudyDays',
      {
        'curriculumId': curriculumId,
        'upserts': {for (final doc in upserts) doc.docId: doc.data},
        'removedConfigIds': removedDocIds,
      },
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
    'upsertGoal',
    {'goalId': goalId, 'data': data},
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
    'endGoal',
    {'goalId': goalId},
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
    'setProfileProgram',
    {'curriculumId': curriculumId, 'data': data},
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
