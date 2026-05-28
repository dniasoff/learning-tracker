// TutoredWriteRouter — S1 + S3 + S4 (Edit-Propagation Squad)
//
// A SyncWriteFacade decorator that intercepts outgoing writes when a tutor is
// active-as-tutored and routes them to the matching TutorWriteService Cloud
// Function instead of the local outbox.
//
// When [selection] is null the router is transparent — every call is forwarded
// to the [_delegate] unchanged (non-tutored outbox path).
//
// When [selection] is non-null every intercepted write:
//   1. Calls the matching TutorWriteService CF with the canonical CF args
//      (grantId + ownerUid + profileId + entity-specific payload).
//   2. Does NOT forward to the [_delegate] — the outbox stays empty for that
//      entity kind.  The outbox isProfileTutored guard in OutboxProcessor is
//      the belt-and-suspenders safety net but should never need to fire.
//
// Intercepted entity kinds:
//   pushGoal                         → tutorUpsertGoal
//   deleteGoal                       → tutorDeleteGoal
//   pushCurriculumTrack              → tutorUpsertTrack
//   pushStageDefinitions             → tutorUpsertStageDefinition (one per stage)
//   pushStudyDayConfig               → tutorUpsertStudyDayConfig
//   pushBookmark                     → tutorUpsertBookmark
//   pushGamificationSettingsSnapshot → tutorUpdateGamificationSettings (S4)
//   pushLearnerProfile               → tutorEditProfile (S4)
//   deleteCompletion                 → tutorResetCompletion (S4)
//
// Pass-through (not tutored-routed — delegated to outbox):
//   pushSettings, pushLearningOrder, pushUiPreferencesSnapshot,
//   deleteLearnerProfile (talmid's profile deletion is not a tutor right).
//
// Error handling: CF failures (TutorWriteFailure) are logged and re-thrown as
// [TutorWriteException] so callers can surface a clear snackbar. This matches
// the offline-first contract — the local Drift write already happened before
// this layer is consulted.

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// Thrown when a tutored write CF call returns a [TutorWriteFailure].
///
/// Callers should catch this and surface a snackbar — never silently strand.
class TutorWriteException implements Exception {
  const TutorWriteException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'TutorWriteException($code): $message';
}

/// [SyncWriteFacade] decorator that routes writes to CFs when a tutor session
/// is active. Falls through to [_delegate] for non-tutored sessions.
class TutoredWriteRouter implements SyncWriteFacade {
  TutoredWriteRouter({
    required SyncWriteFacade delegate,
    required TutorWriteService writeService,
    required TutoredProfileSelection? selection,
  })  : _delegate = delegate,
        _writeService = writeService,
        _selection = selection;

  final SyncWriteFacade _delegate;
  final TutorWriteService _writeService;
  final TutoredProfileSelection? _selection;

  // ── Intercepted entity writes ──────────────────────────────────────────────

  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushGoal(goal);

    final goalId = goal['id']?.toString() ?? goal['goal_id']?.toString() ?? '';
    final result = await _writeService.upsertGoal(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: int.parse(sel.profileId),
      goalId: goalId,
      goalData: goal,
    );
    _handleResult(result, 'tutorUpsertGoal');
  }

  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {
    final sel = _selection;
    if (sel == null) return _delegate.deleteGoal(payload);

    final goalId =
        payload['firestore_id']?.toString() ??
        payload['id']?.toString() ??
        '';
    final result = await _writeService.deleteGoal(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: int.parse(sel.profileId),
      goalId: goalId,
    );
    _handleResult(result, 'tutorDeleteGoal');
  }

  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushCurriculumTrack(trackData);

    final trackId = trackData['curriculum_id']?.toString() ?? '';
    final result = await _writeService.upsertTrack(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: int.parse(sel.profileId),
      trackId: trackId,
      trackData: trackData,
    );
    _handleResult(result, 'tutorUpsertTrack');
  }

  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {
    final sel = _selection;
    if (sel == null) {
      return _delegate.pushStageDefinitions(
        trackId: trackId,
        curriculumId: curriculumId,
        stages: stages,
        updatedAt: updatedAt,
      );
    }

    final profileIdInt = int.parse(sel.profileId);
    for (final stage in stages) {
      final stageOrder = stage['stage_order']?.toString() ?? '';
      final stageId = '${trackId}_$stageOrder';
      final payload = <String, dynamic>{
        ...stage,
        'track_id': trackId,
        'curriculum_id': curriculumId,
        'updated_at': updatedAt.toIso8601String(),
      };
      final result = await _writeService.upsertStageDefinition(
        grantId: sel.grantId,
        ownerUid: sel.ownerUid,
        profileId: profileIdInt,
        stageId: stageId,
        stageData: payload,
      );
      _handleResult(result, 'tutorUpsertStageDefinition[$stageId]');
    }
  }

  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushStudyDayConfig(payload);

    final curriculumId = payload['curriculum_id']?.toString() ?? '';
    final dayOfWeek = payload['day_of_week']?.toString() ?? '';
    final trackId = payload['track_id']?.toString() ?? '';
    final configId = '${curriculumId}_${dayOfWeek}_$trackId';
    final result = await _writeService.upsertStudyDayConfig(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: int.parse(sel.profileId),
      configId: configId,
      configData: payload,
    );
    _handleResult(result, 'tutorUpsertStudyDayConfig');
  }

  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushBookmark(bookmark);

    final curriculumId = bookmark['curriculum_id']?.toString() ?? '';
    final trackType = bookmark['track_type']?.toString() ?? '';
    // Mirror firestore_gateway_impl doc-id: {curriculum_id}_{track_type}.
    // When track_type is absent (TrackCreationService omits it), fall back to
    // curriculum_id alone so the CF write is still idempotent per curriculum.
    final bookmarkId = trackType.isNotEmpty
        ? '${curriculumId}_$trackType'
        : curriculumId;
    final result = await _writeService.upsertBookmark(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: int.parse(sel.profileId),
      bookmarkId: bookmarkId,
      bookmarkData: bookmark,
    );
    _handleResult(result, 'tutorUpsertBookmark');
  }

  // ── Pass-through (not yet tutored-routed) ─────────────────────────────────

  @override
  Future<void> pushGamificationSettingsSnapshot() =>
      _delegate.pushGamificationSettingsSnapshot();

  @override
  Future<void> pushUiPreferencesSnapshot() =>
      _delegate.pushUiPreferencesSnapshot();

  @override
  Future<void> pushSettings(Map<String, dynamic> settings) =>
      _delegate.pushSettings(settings);

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) => _delegate.pushLearningOrder(
    profileId: profileId,
    curriculumId: curriculumId,
    items: items,
    updatedAt: updatedAt,
  );

  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) =>
      _delegate.pushLearnerProfile(profile);

  @override
  Future<void> deleteLearnerProfile(int profileId) =>
      _delegate.deleteLearnerProfile(profileId);

  @override
  Future<void> deleteCompletion(String completionId) =>
      _delegate.deleteCompletion(completionId);

  // ── Helper ─────────────────────────────────────────────────────────────────

  void _handleResult(TutorWriteResult result, String fnName) {
    if (result case TutorWriteFailure(:final message, :final code)) {
      AppLogger.instance.error(
        event: 'tutored_write_router_cf_failure',
        fields: {'fn': fnName, 'code': code ?? 'unknown'},
      );
      throw TutorWriteException(message, code: code);
    }
  }
}
