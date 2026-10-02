// TutorWriteService — S4 (Talmid-View Squad)
//
// Client-side wrapper around the S4 tutor write-path Cloud Functions.
// When a tutor is active-as-tutored (activeTutoredProfileSelectionProvider ≠ null),
// permitted edits must route to these CFs rather than the local outbox, because
// the tutor cannot write the parent's Firestore namespace directly (rules forbid
// client tutor writes — CF-only per §5 of the talmid-view plan).
//
// Each method accepts the grantId + ownerUid + profileId from
// TutoredProfileSelection and the payload specific to that edit type.
//
// Data isolation: every CF writes only to users/{ownerUid}/learner_profiles/{profileId}/…
// The tutor's own local data is never touched.
//
// After a successful CF call the caller is responsible for refreshing the
// local mirror (trigger a tutored pull) so the change is visible in the UI.
//
// Story 1.24 (DNI-486): the learning commands (`recordLearning`,
// `voidLearning`, `replaceLearning`, `unlearn`) call the Story 1.23
// callables and return the decoded result, including the server-stamped
// `recorded_at` the client re-runs `CaptureGate` on (AD-36). Every event id
// and action id is a client ULID the CALLER allocates before the first
// invocation, so a retry after a timeout re-sends the identical payload and
// the callable's idempotent replay returns the stored result (AD-31, AD-38).

import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';

/// Result type for tutor write operations.
sealed class TutorWriteResult {
  const TutorWriteResult();
}

class TutorWriteSuccess extends TutorWriteResult {
  const TutorWriteSuccess();
}

/// A successful Story 1.23 learning callable (DNI-486): the action and the
/// learning events it wrote, with the server-stamped `recorded_at` the
/// client re-runs `CaptureGate` on (AD-36, deviation #2).
class TutorLearningWritten extends TutorWriteSuccess {
  const TutorLearningWritten({
    required this.actionId,
    this.eventIds = const [],
    this.recordedAt,
    this.replayed = false,
  });

  /// The governed action id (a client ULID).
  final String actionId;

  /// The learning events the action wrote (a replay returns the stored ids).
  final List<String> eventIds;

  /// The server-stamped `recorded_at` of the action's events, null when no
  /// event was written.
  final DateTime? recordedAt;

  /// The callable returned an already-stored action (a retry after an
  /// ambiguous timeout): nothing new was written.
  final bool replayed;
}

/// A successful Story 1.10 governed callable (DNI-486): the action id and
/// the `change_log` entries it wrote (AD-38).
class TutorGovernedWritten extends TutorWriteSuccess {
  const TutorGovernedWritten({
    this.actionId,
    this.changeIds = const [],
    this.at,
    this.replayed = false,
  });

  /// The governed action id; null when the server did not return one.
  final String? actionId;

  /// The action's `change_log` entry ids.
  final List<String> changeIds;

  /// The server-stamped `change_log.at`.
  final DateTime? at;

  /// The callable returned an already-stored action.
  final bool replayed;
}

class TutorWriteFailure extends TutorWriteResult {
  const TutorWriteFailure({required this.message, this.code});
  final String message;
  final String? code;

  /// The write may not have reached the server, or its answer was lost (a
  /// timeout, no network, a transient server error). Nothing is shown as
  /// written; a retry re-sends the SAME client ULIDs, so a write that did
  /// commit is replayed, never duplicated (DNI-486 AC-5).
  bool get isRetryable => _retryableCodes.contains(code);

  static const _retryableCodes = {
    'deadline-exceeded',
    'unavailable',
    'aborted',
    'internal',
    'resource-exhausted',
    'unknown',
    'unknown-error',
  };
}

/// AD-53 (DNI-487 AC-6): the callable's per-call grant check rejected the
/// write because the parent turned off "Can edit learning". Nothing was
/// written; the tutor's read access is unchanged. Surfaces show
/// `tutorEditingTurnedOff(learner)` for it (see
/// `tutorWriteFailureMessage`).
class TutorWriteEditingTurnedOff extends TutorWriteFailure {
  const TutorWriteEditingTurnedOff({required super.message})
    : super(code: 'permission-denied');
}

/// The server's AD-53 rejection reads "Grant lacks can_edit_learning"
/// (writeWithChangeLog, verifyTutorGrant and tutorBulkPriorCompletions).
bool _isEditingTurnedOff(FirebaseFunctionsException e) =>
    e.code == 'permission-denied' &&
    (e.message ?? '').contains('can_edit_learning');

/// One tutor `learn` event in the Story 1.23 wire shape (`{id, fields}`,
/// AD-52 storage names). [id] is the client ULID — the `learning_events`
/// doc id — allocated once and re-sent unchanged on retry. The caller
/// never supplies `actor`, `recorded_at` or `original_recorded_at`.
final class TutorLearnEvent {
  /// Creates the event. [dateState] is `dated` (with [learnedOn]) or
  /// `before_tracking` (no [learnedOn]; a node ref carries [level]).
  const TutorLearnEvent({
    required this.id,
    required this.curriculumId,
    required this.ref,
    required this.dateState,
    this.learnedOn,
    this.level,
    this.stage,
  }) : assert(
         dateState != DateState.catchUp,
         'a tutor capture is dated or before_tracking (catch_up is owner-only)',
       );

  /// The client ULID.
  final String id;

  /// The curriculum storage key.
  final String curriculumId;

  /// The leaf ref, or the node ref of a `before_tracking` [level] event.
  final String ref;

  /// `dated` or `before_tracking`.
  final DateState dateState;

  /// `YYYY-MM-DD` for a dated event; null for `before_tracking`.
  final String? learnedOn;

  /// The ContentIndex level of a `before_tracking` node event.
  final String? level;

  /// The review stage of a main-track event.
  final int? stage;

  /// The `{id, fields}` request object. Optional keys are omitted, never
  /// sent as null, except `learned_on` (null on `before_tracking`).
  Map<String, Object?> toWire() => {
    'id': id,
    'fields': {
      'kind': 'learn',
      'curriculum_id': curriculumId,
      'ref': ref,
      'source': 'main',
      'date_state': dateState.storage,
      'learned_on': dateState == DateState.beforeTracking ? null : learnedOn,
      if (level != null) 'level': level,
      if (stage != null) 'stage': stage,
    },
  };
}

/// One counted node event an un-learn voids, with the client ULIDs of the
/// maximal complement nodes re-issued in its place (ruling B9).
final class TutorNodeReissue {
  /// Creates the entry.
  const TutorNodeReissue({required this.targetEventId, required this.reissues});

  /// The node event to void.
  final String targetEventId;

  /// The re-issued `before_tracking` nodes.
  final List<({String eventId, String ref, String level})> reissues;

  /// The `nodeReissues[]` request object.
  Map<String, Object?> toWire() => {
    'targetEventId': targetEventId,
    'reissues': [
      for (final r in reissues)
        {'eventId': r.eventId, 'ref': r.ref, 'level': r.level},
    ],
  };
}

/// Injectable callable: given a function name and args, calls the CF and
/// returns its response data (null when it has none). Production builds it
/// from the active account's named app (DNI-520); overridable in tests.
typedef TutorCallableInvoker =
    Future<Object?> Function(String functionName, Map<String, dynamic> args);

TutorCallableInvoker _accountInvoker(AccountFunctionsResolver resolve) =>
    (functionName, args) async {
      final functions = await resolve();
      final result = await functions
          .httpsCallable(functionName)
          .call<Object?>(args);
      return result.data;
    };

/// Cloud-Functions-backed write proxy for tutor-originated mutations on a
/// tutored child's profile.
///
/// All methods require an active grant (grantId) whose parent_uid == ownerUid
/// and child_profile_id == profileId. The CFs enforce these checks server-side
/// (Admin SDK) — a mismatched call returns permission-denied.
class TutorWriteService {
  /// Pass [invoker] (tests) or [resolveFunctions] (production: the active
  /// account's named-app Cloud Functions client).
  ///
  /// [analytics] receives the registered `capture` event after a
  /// successful learning capture (AD-47: the callables emit nothing).
  TutorWriteService({
    TutorCallableInvoker? invoker,
    AccountFunctionsResolver? resolveFunctions,
    LearningAnalytics? analytics,
  }) : assert(
         invoker != null || resolveFunctions != null,
         'TutorWriteService needs an invoker or a functions resolver',
       ),
       _invoker = invoker ?? _accountInvoker(resolveFunctions!),
       _analytics = analytics;

  final TutorCallableInvoker _invoker;
  final LearningAnalytics? _analytics;

  // ── Internal helper ──────────────────────────────────────────────────────────

  Future<TutorWriteResult> _call(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    final (_, failure) = await _invoke(functionName, args);
    return failure ?? const TutorWriteSuccess();
  }

  /// Invokes [functionName]; its response data, or the typed failure. The
  /// single failure mapping every tutor callable shares.
  Future<(Object?, TutorWriteFailure?)> _invoke(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    try {
      return (await _invoker(functionName, args), null);
    } on FirebaseFunctionsException catch (e) {
      if (_isEditingTurnedOff(e)) {
        return (null, TutorWriteEditingTurnedOff(message: e.message!));
      }
      return (
        null,
        TutorWriteFailure(
          message: e.message ?? 'Cloud Function call failed',
          code: e.code,
        ),
      );
    } catch (e, st) {
      // AUD-tutoring-11: log the real exception for diagnostics, but never
      // stash its raw text in the value a caller may surface to the UI
      // (EH-5). FirebaseFunctionsException already carries a structured
      // code/message (handled above) — this covers only the genuinely
      // unexpected fallback.
      AppLogger.instance.error(
        event: 'TutorWriteService.$functionName unexpected error',
        exception: e,
        stackTrace: st,
      );
      return (
        null,
        const TutorWriteFailure(
          message: 'An unexpected error occurred.',
          code: 'unknown-error',
        ),
      );
    }
  }

  /// A Story 1.10 governed callable: [_invoke], decoded as
  /// [TutorGovernedWritten]. [actionId] (a client ULID) is sent only when
  /// given, so a retry replays the stored action instead of writing twice.
  Future<TutorWriteResult> _callGoverned(
    String functionName,
    Map<String, dynamic> args, {
    String? actionId,
  }) async {
    final (data, failure) = await _invoke(functionName, {
      ...args,
      if (actionId != null) 'actionId': actionId,
    });
    if (failure != null) return failure;
    final map = _asMap(data);
    return TutorGovernedWritten(
      actionId: map['action_id'] as String? ?? actionId,
      changeIds: _stringList(map['change_ids']),
      at: _instant(map['at']),
      replayed: map['replayed'] == true,
    );
  }

  /// A Story 1.23 learning callable: [_invoke], decoded as
  /// [TutorLearningWritten].
  Future<TutorWriteResult> _callLearning(
    String functionName,
    Map<String, dynamic> args, {
    required String actionId,
  }) async {
    final (data, failure) = await _invoke(functionName, args);
    if (failure != null) return failure;
    final map = _asMap(data);
    return TutorLearningWritten(
      actionId: map['action_id'] as String? ?? actionId,
      eventIds: _stringList(map['event_ids']),
      recordedAt: _instant(map['recorded_at']),
      replayed: map['replayed'] == true,
    );
  }

  static Map<Object?, Object?> _asMap(Object? data) =>
      data is Map ? data : const {};

  static List<String> _stringList(Object? raw) => raw is List
      ? [
          for (final v in raw)
            if (v is String) v,
        ]
      : const [];

  /// An ISO-8601 server stamp, as UTC; null when absent or malformed.
  static DateTime? _instant(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  // ── Learning events (Story 1.23 callables, DNI-486) ─────────────────────────
  //
  // Wire shapes are the Story 1.23 contract (functions/src/tutor_learning.ts);
  // no field is added here. The caller supplies every client ULID.

  /// Records [events] (`learn`, `source = main`) for the talmid through
  /// `tutorRecordLearning`. [actionId] defaults, on the server, to the first
  /// event's id — the same value is passed here so a retry is stable.
  ///
  /// After a successful, newly written capture it emits the registered
  /// `capture` event through [LearningAnalytics] — once per curriculum and
  /// date state, enums and a count only (AD-47). A failure, or a replay of
  /// an already-stored action (a retry after a lost answer), emits nothing.
  Future<TutorWriteResult> recordLearning({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required List<TutorLearnEvent> events,
    String? actionId,
  }) async {
    assert(events.isNotEmpty, 'recordLearning needs at least one event');
    final action = actionId ?? events.first.id;
    final result = await _callLearning('tutorRecordLearning', {
      'grantId': grantId,
      'ownerUid': ownerUid,
      'profileId': profileId,
      'actionId': action,
      'events': [for (final e in events) e.toWire()],
    }, actionId: action);
    if (result is TutorLearningWritten && !result.replayed) {
      _emitCapture(events);
    }
    return result;
  }

  void _emitCapture(List<TutorLearnEvent> events) {
    final analytics = _analytics;
    if (analytics == null) return;
    final counts = <(String, DateState), int>{};
    for (final e in events) {
      final key = (e.curriculumId, e.dateState);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final MapEntry(key: (curriculumId, dateState), value: count)
        in counts.entries) {
      analytics.capture(
        curriculumId: curriculumId,
        sourceKind: CaptureSourceKind.main,
        dateState: dateState,
        count: count,
      );
    }
  }

  /// Voids the `learn` event [targetId] with the void event [eventId]
  /// through `tutorVoidLearning` (AD-31: the server rejects a non-learn
  /// target).
  Future<TutorWriteResult> voidLearning({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String eventId,
    required String targetId,
  }) => _callLearning('tutorVoidLearning', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'actionId': eventId,
    'eventId': eventId,
    'targetId': targetId,
  }, actionId: eventId);

  /// Replaces [targetId]: its void [eventId] plus the corrected learn event
  /// [replacement], in ONE `tutorVoidLearning` transaction (the server
  /// stamps the copy's `original_recorded_at = effectiveAt(target)`).
  Future<TutorWriteResult> replaceLearning({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String eventId,
    required String targetId,
    required TutorLearnEvent replacement,
  }) => _callLearning('tutorVoidLearning', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'actionId': eventId,
    'eventId': eventId,
    'targetId': targetId,
    'replacement': replacement.toWire(),
  }, actionId: eventId);

  /// Un-learns [leafSet] of [curriculumId] (AD-31) through `tutorUnlearn`,
  /// carrying the client-computed plan's [nodeReissues] (ruling B9).
  /// [actionId] is required: the server mints the void ids, so only the
  /// client action id makes a retry replay instead of re-plan.
  Future<TutorWriteResult> unlearn({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String actionId,
    required String curriculumId,
    required List<String> leafSet,
    List<TutorNodeReissue> nodeReissues = const [],
  }) => _callLearning('tutorUnlearn', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'actionId': actionId,
    'curriculumId': curriculumId,
    'leafSet': leafSet,
    'nodeReissues': [for (final n in nodeReissues) n.toWire()],
  }, actionId: actionId);

  // ── Completion reset (canEditLearning, AD-53) ────────────────────────────────────

  /// Deletes a completion document from the child's profile as a correction.
  Future<TutorWriteResult> resetCompletion({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String completionId,
  }) => _call('tutorResetCompletion', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'completionId': completionId,
  });

  // ── Main-track governed (Story 1.10 callables via writeWithChangeLog) ──────
  //
  // Each governed method takes an optional client [actionId] ULID: pass the
  // same one on a retry so the server replays the stored action (AD-38).

  // ── Goals (canEditLearning, AD-53) ─────────────────────────────────────────────────────

  /// Creates or updates a goal document in the child's profile.
  Future<TutorWriteResult> upsertGoal({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String goalId,
    required Map<String, dynamic> goalData,
    String? actionId,
  }) => _callGoverned('tutorUpsertGoal', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'goalId': goalId,
    'goalData': goalData,
  }, actionId: actionId);

  /// Deletes a goal document from the child's profile.
  Future<TutorWriteResult> deleteGoal({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String goalId,
    String? actionId,
  }) => _callGoverned('tutorDeleteGoal', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'goalId': goalId,
  }, actionId: actionId);

  // ── Tracks (canEditLearning, AD-53) ───────────────────────────────────────────────────

  /// Creates or updates a curriculum_tracks document in the child's profile.
  Future<TutorWriteResult> upsertTrack({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String trackId,
    required Map<String, dynamic> trackData,
    String? actionId,
  }) => _callGoverned('tutorUpsertTrack', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'trackId': trackId,
    'trackData': trackData,
  }, actionId: actionId);

  /// Deletes a curriculum_tracks document from the child's profile.
  Future<TutorWriteResult> deleteTrack({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String trackId,
    String? actionId,
  }) => _callGoverned('tutorDeleteTrack', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'trackId': trackId,
  }, actionId: actionId);

  // ── Stage definitions (canEditLearning, AD-53) ───────────────────────────────────────

  /// Creates or updates a stage_definitions document in the child's profile.
  Future<TutorWriteResult> upsertStageDefinition({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String stageId,
    required Map<String, dynamic> stageData,
    String? actionId,
  }) => _callGoverned('tutorUpsertStageDefinition', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'stageId': stageId,
    'stageData': stageData,
  }, actionId: actionId);

  // ── Study day configs (canEditLearning, AD-53) ─────────────────────────────────────

  /// Creates or updates a study_day_configs document in the child's profile.
  Future<TutorWriteResult> upsertStudyDayConfig({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String configId,
    required Map<String, dynamic> configData,
    String? actionId,
  }) => _callGoverned('tutorUpsertStudyDayConfig', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'configId': configId,
    'configData': configData,
  }, actionId: actionId);

  /// Deletes a study_day_configs document from the child's profile.
  Future<TutorWriteResult> deleteStudyDayConfig({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String configId,
    String? actionId,
  }) => _callGoverned('tutorDeleteStudyDayConfig', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'configId': configId,
  }, actionId: actionId);

  /// Replaces [curriculumId]'s study-day schedule as ONE governed action
  /// through `tutorReplaceStudyDays` (Story 1.24, DNI-486): every upsert in
  /// [upserts] (config id → storage fields) and every `ended_at` tombstone
  /// in [removedConfigIds] is one `mainTrackStudyDays` change_log entry
  /// under the one [actionId], written in one server transaction — all or
  /// nothing.
  Future<TutorWriteResult> replaceStudyDays({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String curriculumId,
    required Map<String, Map<String, dynamic>> upserts,
    List<String> removedConfigIds = const [],
    String? actionId,
  }) => _callGoverned('tutorReplaceStudyDays', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'curriculumId': curriculumId,
    'upserts': [
      for (final MapEntry(key: configId, value: configData) in upserts.entries)
        {'configId': configId, 'configData': configData},
    ],
    'removedConfigIds': removedConfigIds,
  }, actionId: actionId);

  // ── Gamification settings: rewards + points ──────────────────────────────────

  /// Merges into preferences/gamification_settings — covers reward catalogue and
  /// points config. Pass [permKey] = 'can_edit_rewards' or 'can_edit_points'
  /// depending on which concern the [settingsData] affects.
  Future<TutorWriteResult> updateGamificationSettings({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String permKey,
    required Map<String, dynamic> settingsData,
  }) => _call('tutorUpdateGamificationSettings', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'permKey': permKey,
    'settingsData': settingsData,
  });

  // ── Profile program (canEditLearning, AD-53) ──────────────────────────────────────────

  /// Creates or updates a profile_programs document in the child's profile.
  Future<TutorWriteResult> setProfileProgram({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String programId,
    required Map<String, dynamic> programData,
    String? actionId,
  }) => _callGoverned('tutorSetProfileProgram', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'programId': programId,
    'programData': programData,
  }, actionId: actionId);

  // ── Curriculum scope (canEditLearning, AD-53) ─────────────────────────────────────────

  /// Creates or updates a curriculum_scopes document in the child's profile.
  Future<TutorWriteResult> upsertCurriculumScope({
    required String grantId,
    required String ownerUid,
    required String profileId,
    required String scopeId,
    required Map<String, dynamic> scopeData,
    String? actionId,
  }) => _callGoverned('tutorUpsertCurriculumScope', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'scopeId': scopeId,
    'scopeData': scopeData,
  }, actionId: actionId);

  // ── Profile edit (always allowed for active tutors) ──────────────────────────

  /// Updates display_name, avatar, and/or mode on the child's learner_profiles doc.
  /// At least one field must be non-null.
  Future<TutorWriteResult> editProfile({
    required String grantId,
    required String ownerUid,
    required String profileId,
    String? displayName,
    String? avatar,
    String? mode,
  }) {
    assert(
      displayName != null || avatar != null || mode != null,
      'editProfile: at least one of displayName, avatar, mode must be non-null',
    );
    return _call('tutorEditProfile', {
      'grantId': grantId,
      'ownerUid': ownerUid,
      'profileId': profileId,
      if (displayName != null) 'displayName': displayName,
      if (avatar != null) 'avatar': avatar,
      if (mode != null) 'mode': mode,
    });
  }
}
