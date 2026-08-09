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
//   pushProfileProgram               → tutorSetProfileProgram
//   pushGamificationSettingsSnapshot → tutorUpdateGamificationSettings (S4)
//   pushLearnerProfile               → tutorEditProfile (S4)
//   deleteCompletion                 → tutorResetCompletion (S4)
//
// Pass-through (not tutored-routed — delegated to outbox):
//   pushSettings, pushLearningOrder, pushUiPreferencesSnapshot, pushBookmark
//   (T-34: this router no longer routes bookmark writes to a CF — the
//   `tutorUpsertBookmark` CF still exists but nothing in lib/ calls it),
//   deleteLearnerProfile (talmid's profile deletion is not a tutor right).
//
// Error handling: CF failures (TutorWriteFailure) are logged and re-thrown as
// [TutorWriteException] so callers can surface a clear snackbar. This matches
// the offline-first contract — the local Drift write already happened before
// this layer is consulted.
//
// AUD-tutoring-07 — partial multi-stage failure (pushStageDefinitions):
// stage upserts are sequential CF calls, not one atomic batch. If a call
// fails partway through, the earlier stages have already committed
// server-side and there is no local outbox to pick them back up (see
// above — tutored writes deliberately bypass the outbox). Decision:
// accepted as a surfaced-not-silent risk, not an automatic retry path.
// [TutorWriteException.succeededStageIds] carries the stage IDs that
// committed before the failing one so the caller can decide whether to
// retry just the remaining subset instead of losing state silently.
//
// AUD-tutoring-17 — every method above parses [_selection.profileId] via
// the private [TutoredWriteRouter._profileIdOrThrow] helper (not a bare
// `int.parse`) so a malformed profileId honors the same documented
// TutorWriteException contract instead of leaking a raw FormatException
// that `on TutorWriteException` callers would miss.

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// Thrown when a tutored write CF call returns a [TutorWriteFailure].
///
/// Callers should catch this and surface a snackbar — never silently strand.
class TutorWriteException implements Exception {
  const TutorWriteException(
    this.message, {
    this.code,
    this.succeededStageIds = const [],
  });
  final String message;
  final String? code;

  /// AUD-tutoring-07 — for [TutoredWriteRouter.pushStageDefinitions], the
  /// stage IDs (`{trackId}_{stageOrder}`) that already committed
  /// server-side before this failure. Empty for every other (single-write)
  /// failure. Lets the caller retry just the remaining subset instead of
  /// losing the partial-success state silently.
  final List<String> succeededStageIds;

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
    Future<Map<String, dynamic>> Function()? gamificationSnapshotBuilder,
  }) : _delegate = delegate,
       _writeService = writeService,
       _selection = selection,
       _gamificationSnapshotBuilder = gamificationSnapshotBuilder;

  final SyncWriteFacade _delegate;
  final TutorWriteService _writeService;
  final TutoredProfileSelection? _selection;
  final Future<Map<String, dynamic>> Function()? _gamificationSnapshotBuilder;

  // ── Intercepted entity writes ──────────────────────────────────────────────

  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushGoal(goal);

    final goalId = goal['id']?.toString() ?? goal['goal_id']?.toString() ?? '';
    final result = await _writeService.upsertGoal(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: _profileIdOrThrow(sel),
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
        payload['firestore_id']?.toString() ?? payload['id']?.toString() ?? '';
    final result = await _writeService.deleteGoal(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: _profileIdOrThrow(sel),
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
      profileId: _profileIdOrThrow(sel),
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

    final profileId = _profileIdOrThrow(sel);
    // AUD-tutoring-07: track which stages already committed so a mid-loop
    // CF failure can name them instead of throwing an opaque exception —
    // see the class header for the accepted-risk decision.
    final succeededStageIds = <String>[];
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
        profileId: profileId,
        stageId: stageId,
        stageData: payload,
      );
      if (result case TutorWriteFailure(:final message, :final code)) {
        AppLogger.instance.error(
          event: 'tutored_write_router_cf_failure',
          fields: {
            'fn': 'tutorUpsertStageDefinition[$stageId]',
            'code': code ?? 'unknown',
            'succeededStageIds': succeededStageIds.join(','),
          },
        );
        throw TutorWriteException(
          message,
          code: code,
          succeededStageIds: List.unmodifiable(succeededStageIds),
        );
      }
      succeededStageIds.add(stageId);
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
      profileId: _profileIdOrThrow(sel),
      configId: configId,
      configData: payload,
    );
    _handleResult(result, 'tutorUpsertStudyDayConfig');
  }

  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushProfileProgram(payload);

    // C1 fix: use curriculum_id as the doc-id (matches parent-side gateway).
    final docId = payload['curriculum_id']?.toString() ?? '';
    final result = await _writeService.setProfileProgram(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: _profileIdOrThrow(sel),
      programId: docId,
      programData: payload,
    );
    _handleResult(result, 'tutorSetProfileProgram');
  }

  // ── S4: gamification / profile edit / completion reset ────────────────────

  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    final sel = _selection;
    if (sel == null) return _delegate.pushGamificationSettingsSnapshot();

    // Build the snapshot via the injected builder (OutboxSyncWriteFacade.
    // buildGamificationSnapshot). Falls back to delegate if builder absent.
    final builder = _gamificationSnapshotBuilder;
    if (builder == null) return _delegate.pushGamificationSettingsSnapshot();

    final settingsData = await builder();
    final profileId = _profileIdOrThrow(sel);

    // R3-H2 fix: call CF twice — once per permission key — so a tutor with
    // only can_edit_points or only can_edit_rewards is not locked out.
    // The CF uses set(merge:true), so each write merges cleanly.
    final rewardsSlice = <String, dynamic>{};
    final pointsSlice = <String, dynamic>{};
    for (final entry in settingsData.entries) {
      if (entry.key == 'reward_settings') {
        rewardsSlice[entry.key] = entry.value;
      } else if (entry.key == 'points_config') {
        pointsSlice[entry.key] = entry.value;
      } else {
        rewardsSlice[entry.key] = entry.value;
        pointsSlice[entry.key] = entry.value;
      }
    }

    if (rewardsSlice.isNotEmpty) {
      final result = await _writeService.updateGamificationSettings(
        grantId: sel.grantId,
        ownerUid: sel.ownerUid,
        profileId: profileId,
        permKey: 'can_edit_rewards',
        settingsData: rewardsSlice,
      );
      _handleResult(
        result,
        'tutorUpdateGamificationSettings[can_edit_rewards]',
      );
    }
    if (pointsSlice.isNotEmpty) {
      final result = await _writeService.updateGamificationSettings(
        grantId: sel.grantId,
        ownerUid: sel.ownerUid,
        profileId: profileId,
        permKey: 'can_edit_points',
        settingsData: pointsSlice,
      );
      _handleResult(result, 'tutorUpdateGamificationSettings[can_edit_points]');
    }
  }

  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    final sel = _selection;
    if (sel == null) return _delegate.pushLearnerProfile(profile);

    // Extract editable fields — handle both camelCase and snake_case keys.
    final displayName =
        (profile['displayName'] ?? profile['display_name']) as String?;
    // avatar_index may be an int from Drift or a String from a caller — convert.
    final avatarRaw = profile['avatar'] ?? profile['avatar_index'];
    final avatar = avatarRaw?.toString();
    final mode = profile['mode'] as String?;

    if (displayName == null && avatar == null && mode == null) {
      AppLogger.instance.debug(
        event: 'tutored_write_router_profile_no_editable_fields',
        fields: {'keys': profile.keys.toList().toString()},
      );
      return;
    }

    final result = await _writeService.editProfile(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: _profileIdOrThrow(sel),
      displayName: displayName,
      avatar: avatar,
      mode: mode,
    );
    _handleResult(result, 'tutorEditProfile');
  }

  @override
  Future<void> deleteCompletion(String completionId) async {
    final sel = _selection;
    if (sel == null) return _delegate.deleteCompletion(completionId);

    final result = await _writeService.resetCompletion(
      grantId: sel.grantId,
      ownerUid: sel.ownerUid,
      profileId: _profileIdOrThrow(sel),
      completionId: completionId,
    );
    _handleResult(result, 'tutorResetCompletion');
  }

  // ── Pass-through (not tutored-routed) ─────────────────────────────────────

  @override
  Future<void> pushUiPreferencesSnapshot() =>
      _delegate.pushUiPreferencesSnapshot();

  @override
  Future<void> pushSettings(Map<String, dynamic> settings) =>
      _delegate.pushSettings(settings);

  // T-34: no tutor-write CF route for bookmarks in this router. The prior
  // implementation intercepted this call and routed it to `tutorUpsertBookmark`
  // using a doc-id formula (`{curriculum_id}_{track_type}`) that did not match
  // what `firestore_gateway_impl.dart` actually writes for bookmarks (a bare
  // `curriculum_id` — `BookmarkEntity` has no `track_type` field), so it
  // produced a doc id nothing else agreed on. It was also unreachable from
  // production: this router is only ever handed to `BookmarkRepositoryImpl`,
  // which nothing under lib/ constructs (the live provider builds
  // `FirestoreBookmarkRepositoryAdapter`, which refuses tutored bookmark
  // writes outright). Deleted rather than fixed; see docs/planning/
  // firestore-cutover-log.md, 2026-08-06 T-34 entry.
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) =>
      _delegate.pushBookmark(bookmark);

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
  Future<void> deleteLearnerProfile(String profileId) =>
      _delegate.deleteLearnerProfile(profileId);

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

  /// AUD-tutoring-17 — validates [sel.profileId] as a non-empty string (ULID), matching this
  /// class's documented error contract (see header): a malformed profileId
  /// is logged via [AppLogger] and re-thrown as a [TutorWriteException]
  /// rather than propagating a raw error that callers catching
  /// `on TutorWriteException` would not see.
  String _profileIdOrThrow(TutoredProfileSelection sel) {
    final raw = sel.profileId;
    if (raw.isEmpty) {
      AppLogger.instance.error(
        event: 'tutored_write_router_invalid_profile_id',
        fields: {'profileId': raw},
      );
      throw TutorWriteException(
        'Invalid tutored profile id: "$raw"',
        code: 'invalid-profile-id',
      );
    }
    return raw;
  }
}
