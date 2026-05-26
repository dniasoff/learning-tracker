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

import 'package:cloud_functions/cloud_functions.dart';

/// Result type for tutor write operations.
sealed class TutorWriteResult {
  const TutorWriteResult();
}

class TutorWriteSuccess extends TutorWriteResult {
  const TutorWriteSuccess();
}

class TutorWriteFailure extends TutorWriteResult {
  const TutorWriteFailure({required this.message, this.code});
  final String message;
  final String? code;
}

/// Injectable callable: given a function name and args, calls the CF.
/// Defaults to FirebaseFunctions.instance; overridable in tests.
typedef TutorCallableInvoker =
    Future<void> Function(String functionName, Map<String, dynamic> args);

Future<void> _defaultInvoker(
  String functionName,
  Map<String, dynamic> args,
) async {
  await FirebaseFunctions.instance
      .httpsCallable(functionName)
      .call<Map<String, dynamic>>(args);
}

/// Cloud-Functions-backed write proxy for tutor-originated mutations on a
/// tutored child's profile.
///
/// All methods require an active grant (grantId) whose parent_uid == ownerUid
/// and child_profile_id == profileId. The CFs enforce these checks server-side
/// (Admin SDK) — a mismatched call returns permission-denied.
class TutorWriteService {
  TutorWriteService({TutorCallableInvoker? invoker})
    : _invoker = invoker ?? _defaultInvoker;

  final TutorCallableInvoker _invoker;

  // ── Internal helper ──────────────────────────────────────────────────────────

  Future<TutorWriteResult> _call(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    try {
      await _invoker(functionName, args);
      return const TutorWriteSuccess();
    } on FirebaseFunctionsException catch (e) {
      return TutorWriteFailure(
        message: e.message ?? 'Cloud Function call failed',
        code: e.code,
      );
    } catch (e) {
      return TutorWriteFailure(message: e.toString());
    }
  }

  // ── Completion reset (canResetCompletion) ────────────────────────────────────

  /// Deletes a completion document from the child's profile as a correction.
  Future<TutorWriteResult> resetCompletion({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String completionId,
  }) => _call('tutorResetCompletion', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'completionId': completionId,
  });

  // ── Goals (canEditGoals) ─────────────────────────────────────────────────────

  /// Creates or updates a goal document in the child's profile.
  Future<TutorWriteResult> upsertGoal({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String goalId,
    required Map<String, dynamic> goalData,
  }) => _call('tutorUpsertGoal', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'goalId': goalId,
    'goalData': goalData,
  });

  /// Deletes a goal document from the child's profile.
  Future<TutorWriteResult> deleteGoal({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String goalId,
  }) => _call('tutorDeleteGoal', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'goalId': goalId,
  });

  // ── Tracks (canEditStages) ───────────────────────────────────────────────────

  /// Creates or updates a curriculum_tracks document in the child's profile.
  Future<TutorWriteResult> upsertTrack({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String trackId,
    required Map<String, dynamic> trackData,
  }) => _call('tutorUpsertTrack', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'trackId': trackId,
    'trackData': trackData,
  });

  /// Deletes a curriculum_tracks document from the child's profile.
  Future<TutorWriteResult> deleteTrack({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String trackId,
  }) => _call('tutorDeleteTrack', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'trackId': trackId,
  });

  // ── Stage definitions (canEditStages) ───────────────────────────────────────

  /// Creates or updates a stage_definitions document in the child's profile.
  Future<TutorWriteResult> upsertStageDefinition({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String stageId,
    required Map<String, dynamic> stageData,
  }) => _call('tutorUpsertStageDefinition', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'stageId': stageId,
    'stageData': stageData,
  });

  // ── Study day configs (canEditStudyDays) ─────────────────────────────────────

  /// Creates or updates a study_day_configs document in the child's profile.
  Future<TutorWriteResult> upsertStudyDayConfig({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String configId,
    required Map<String, dynamic> configData,
  }) => _call('tutorUpsertStudyDayConfig', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'configId': configId,
    'configData': configData,
  });

  /// Deletes a study_day_configs document from the child's profile.
  Future<TutorWriteResult> deleteStudyDayConfig({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String configId,
  }) => _call('tutorDeleteStudyDayConfig', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'configId': configId,
  });

  // ── Gamification settings: rewards + points ──────────────────────────────────

  /// Merges into preferences/gamification_settings — covers reward catalogue and
  /// points config. Pass [permKey] = 'can_edit_rewards' or 'can_edit_points'
  /// depending on which concern the [settingsData] affects.
  Future<TutorWriteResult> updateGamificationSettings({
    required String grantId,
    required String ownerUid,
    required int profileId,
    required String permKey,
    required Map<String, dynamic> settingsData,
  }) => _call('tutorUpdateGamificationSettings', {
    'grantId': grantId,
    'ownerUid': ownerUid,
    'profileId': profileId,
    'permKey': permKey,
    'settingsData': settingsData,
  });

  // ── Profile edit (always allowed for active tutors) ──────────────────────────

  /// Updates display_name, avatar, and/or mode on the child's learner_profiles doc.
  /// At least one field must be non-null.
  Future<TutorWriteResult> editProfile({
    required String grantId,
    required String ownerUid,
    required int profileId,
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
