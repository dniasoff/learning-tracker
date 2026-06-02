import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Default study days: all 7 days active (Sun–Shabbos).
///
/// ISO weekdays: Mon=1 ... Sun=7.
const kDefaultStudyDays = <int, String>{
  7: 'study', // Sunday
  1: 'study', // Monday
  2: 'study', // Tuesday
  3: 'study', // Wednesday
  4: 'study', // Thursday
  5: 'study', // Friday
  6: 'study', // Shabbos (Saturday)
};

/// Creates a track in the database from an [AddTrackResult].
///
/// All core DB writes (stages, study days, scopes, point seeds) run in one
/// transaction. Goals are removed first (with sync), then re-created after if
/// the flow includes a goal. Program enrollment is set or cleared after.
class TrackCreationService {
  TrackCreationService({
    required UserDatabase database,
    required CurriculumActivationService activationService,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
    required StageDefinitionRepository stageRepository,
    FirestoreGateway? gateway,
    SyncWriteFacade? syncFacade,
    AnalyticsService? analytics,
  }) : _database = database,
       _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository,
       _stageRepository = stageRepository,
       _gateway = gateway,
       _syncFacade = syncFacade,
       _analytics = analytics ?? const NullAnalyticsService();

  final UserDatabase _database;
  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;
  final StageDefinitionRepository _stageRepository;
  final FirestoreGateway? _gateway;
  // All routable writes (bookmark, study-day, profile-program) go through the
  // tutored router when a tutor session is active.
  final SyncWriteFacade? _syncFacade;
  final AnalyticsService _analytics;

  /// Persist all track configuration from the AddTrackFlow result.
  ///
  /// D7: the track row, stage seeding, study days, scopes, point seeds and the
  /// LOCAL program-enrolment row all run in a SINGLE transaction, so a
  /// stage-seed failure (e.g. an FK error on a profile-less account) rolls back
  /// the track row AND the program row together — no orphaned 0-stage track or
  /// dangling enrolment. Network / idempotent work (curriculum activation, goal
  /// sync, cloud pushes) runs AFTER commit so the transaction is never held
  /// open on a network round.
  Future<void> createTrack({
    required AddTrackResult result,
    required int profileId,
  }) async {
    final curriculum = result.curriculumId;
    final (:bookmarkRef, :trackingStartDate) = result.programId == null
        ? (bookmarkRef: null, trackingStartDate: null)
        : _parseProgramStartingRef(result.startingRef);

    late int trackId;
    var clearedProgram = false;

    await _database.transaction(() async {
      // Restore any soft-deleted track row (avoids UNIQUE violation on re-add).
      trackId = await _database.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: curriculum,
      );

      // Clear any prior stage rows for this (possibly soft-deleted then
      // restored) track before reseeding below.
      await _stageRepository.deleteStagesForTrack(trackId);
      // Stages are seeded from the learning-process (chazara) wizard. When the
      // add-track flow skipped that step (wizardResult == null — e.g. a track
      // created without configuring chazara), fall back to a לימוד-only
      // ("no review") configuration. Every track MUST carry at least the
      // primary learning stage: the scheduler's projection does
      // `if (stages.isEmpty) continue;`, so a stage-less track is skipped
      // entirely and the dashboard shows "No projection" / 0 due despite a
      // valid goal + computed pace. A noReview result seeds ONLY the learn
      // stage — no chazara rounds — honouring the per-track chazara rule.
      // applyWizardResult clears existing stages first (clearFirst: true).
      final wizardResult =
          result.wizardResult?.wizardResult ??
          WizardResult(curriculumId: curriculum, choice: WizardChoice.noReview);
      await _wizardService.applyWizardResult(
        wizardResult,
        profileId: profileId,
        trackId: trackId,
      );

      await _saveStudyDaysLocal(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
        studyDays: result.studyDays,
      );

      await _database.curriculumScopeDao.clearScopesForTrack(trackId);
      if (result.scopeSelections != null &&
          result.scopeSelections!.isNotEmpty) {
        await _saveScopes(
          profileId: profileId,
          curriculumId: curriculum,
          trackId: trackId,
          scopes: result.scopeSelections!,
        );
      }

      await _seedPointConfigsIfNeeded(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
      );

      // Program-enrolment LOCAL row (or clear) — in the SAME transaction so a
      // stage-seed failure above rolls it back too.
      if (result.programId == null) {
        final removed = await _database.profileProgramDao
            .clearProgramForProfileAndCurriculum(
              profileId,
              curriculum.storageKey,
            );
        clearedProgram = removed > 0;
      } else {
        await _database.profileProgramDao.setProfileProgram(
          profileId: profileId,
          curriculumType: curriculum.storageKey,
          programId: result.programId!,
          trackingStartDate: trackingStartDate,
          trackingStartRef: bookmarkRef,
        );
        if (bookmarkRef != null && bookmarkRef.isNotEmpty) {
          await _database.bookmarkDao.upsertBookmarkByProfile(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            sefariaRef: bookmarkRef,
            updatedAt: DateTimeFactory.nowUtc(),
          );
        }
      }
    });

    // ── post-commit: idempotent activation, goal sync, cloud pushes ──────────

    // Activate the curriculum in active_curricula (idempotent). A soft-deleted
    // track can exist without an active_curricula row, so we always attempt it.
    try {
      await _activationService.activateForProfile(curriculum, profileId);
    } catch (_) {
      AppLogger.instance.debug(
        event:
            'TrackCreationService: curriculum ${curriculum.storageKey} '
            'activation skipped (likely already active)',
      );
    }

    await _deleteExistingGoals(trackId);
    await _recreateGoal(
      result: result,
      profileId: profileId,
      curriculum: curriculum,
      trackId: trackId,
    );

    // Cloud pushes (network) — fire after the local state is durable.
    await _pushStudyDaysCloud(
      profileId: profileId,
      curriculumId: curriculum,
      trackId: trackId,
      studyDays: result.studyDays,
    );
    if (result.programId == null) {
      if (clearedProgram) {
        await _gateway?.removeProfileProgramAssignment(
          profileId: profileId,
          curriculumStorageKey: curriculum.storageKey,
        );
      }
    } else {
      if (bookmarkRef != null && bookmarkRef.isNotEmpty) {
        // Phase 1 — route the bookmark write through the outbox so offline
        // track-creates do not silently drop the bookmark.
        await _syncFacade?.pushBookmark({
          'curriculum_id': curriculum.storageKey,
          'content_item_id': bookmarkRef,
          'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
        });
      }
      // Phase 1 — route the profile-program assignment through syncFacade so
      // tutored sessions call tutorSetProfileProgram instead of the outbox.
      await _syncFacade?.pushProfileProgram({
        'profile_id': profileId,
        'curriculum_id': curriculum.storageKey,
        'program_id': result.programId,
        'tracking_start_date': trackingStartDate?.toIso8601String(),
        'tracking_start_ref': bookmarkRef,
        'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
      });
    }

    AppLogger.instance.info(
      event:
          'TrackCreationService: track "${result.label}" created for '
          '${curriculum.storageKey} (profile=$profileId)',
    );

    // Story 27.14 (DNI-390): fire analytics event after successful track creation.
    unawaited(_analytics.logTrackAdded(curriculumId: curriculum.storageKey));
  }

  /// Delete all existing goals for [trackId], syncing tombstones so
  /// re-add does not stack duplicates.
  Future<void> _deleteExistingGoals(int trackId) async {
    final existingGoals = await _database.goalDao.getGoalsByTrack(trackId);
    for (final g in existingGoals) {
      await _goalRepository.deleteGoal(g.id);
    }
  }

  /// Create the goal from [result] if one is present.
  ///
  /// Falls back to [result.label] as the goal description when the [GoalEntity]
  /// carries an empty description — this covers tracks created before B4 was
  /// fixed and any code path that does not seed [GoalEntity.description].
  Future<void> _recreateGoal({
    required AddTrackResult result,
    required int profileId,
    required CurriculumId curriculum,
    required int trackId,
  }) async {
    if (result.goalResult == null) return;
    final goal = result.goalResult!;
    // Use the track label as the description when the goal entity has none
    // (belt-and-suspenders: step_goal seeds it, but older flows may not).
    final description = goal.description.isNotEmpty
        ? goal.description
        : result.label;
    await _goalRepository.createGoal(
      profileId: profileId,
      curriculumId: curriculum,
      trackId: trackId,
      targetPercent: goal.targetPercent,
      paceTarget: goal.paceTarget,
      description: description,
      dateType: goal.dateType,
      paceGranularity: goal.paceGranularityKey,
    );
  }

  /// Parse the raw startingRef string into a bookmark ref and tracking-start date.
  ///
  /// The format may be:
  ///   - null → start from beginning
  ///   - "offset:N|ref:<sefariaRef>" → calendar offset + resolved unit
  ///   - "offset:N" → legacy day-offset format
  ///   - a sefariaRef string (e.g. "Berakhot 42a") → content-based position
  ({String? bookmarkRef, DateTime? trackingStartDate}) _parseProgramStartingRef(
    String? rawStartingRef,
  ) {
    var bookmarkRef = rawStartingRef;
    String? offsetToken;

    if (rawStartingRef != null && rawStartingRef.contains('|')) {
      for (final token in rawStartingRef.split('|')) {
        if (token.startsWith('offset:')) offsetToken = token;
        if (token.startsWith('ref:')) {
          final parsedRef = token.substring('ref:'.length);
          if (parsedRef.isNotEmpty) {
            bookmarkRef = parsedRef;
          }
        }
      }
    }

    DateTime? trackingStartDate;
    final offsetSource =
        offsetToken ??
        ((rawStartingRef != null && rawStartingRef.startsWith('offset:'))
            ? rawStartingRef
            : null);
    if (offsetSource != null) {
      final offset = int.tryParse(offsetSource.substring('offset:'.length));
      if (offset != null) {
        // Two producers feed this token with OPPOSITE sign conventions:
        //  - the canonical typed grammar (ProgramStartingPosition.toLegacyGrammar)
        //    emits a POSITIVE offset for a back-date ("offset:5" = 5 days ago);
        //  - the live add-track calendar UI emits a NEGATIVE offset
        //    ("offset:-5" = 5 days ago).
        // Future start dates are never valid (B2: window is [today − 30, today]),
        // so a back-date is unambiguously today minus the offset magnitude.
        // Mirroring ProgramStartingPosition.fromLegacyGrammar (which uses
        // today.subtract(offset.abs())), we resolve both conventions to the
        // past, capped at the 30-day look-back window.
        final lookBackDays = offset.abs().clamp(0, kMaxLookBackDays);
        trackingStartDate = DateTimeFactory.nowUtc().subtract(
          Duration(days: lookBackDays),
        );
      }
    }

    return (bookmarkRef: bookmarkRef, trackingStartDate: trackingStartDate);
  }

  /// Write study-day config rows for [trackId] (LOCAL only — runs inside the
  /// creation transaction). Cloud push is deferred to [_pushStudyDaysCloud].
  Future<void> _saveStudyDaysLocal({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required Map<int, String> studyDays,
  }) async {
    final dao = _database.studyDayConfigDao;
    await dao.deleteConfigsByCurriculumAndProfile(
      curriculumId.storageKey,
      profileId,
    );
    for (final entry in studyDays.entries) {
      await dao.upsertDayConfig(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        trackId: trackId,
        dayOfWeek: entry.key,
        dayType: entry.value,
      );
    }
  }

  /// Push the study-day configs to the cloud (network — runs AFTER commit).
  ///
  /// The cloud doc-id is derived from (curriculum_id, day_of_week, track_id)
  /// so repeated upserts collapse to one document, matching the local PK.
  Future<void> _pushStudyDaysCloud({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required Map<int, String> studyDays,
  }) async {
    final facade = _syncFacade;
    if (facade == null) return;
    for (final entry in studyDays.entries) {
      await facade.pushStudyDayConfig({
        'profile_id': profileId,
        'curriculum_id': curriculumId.storageKey,
        'track_id': trackId,
        'day_of_week': entry.key,
        'day_type': entry.value,
        'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
      });
    }
  }

  Future<void> _saveScopes({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required List<ScopeEntry> scopes,
  }) async {
    final now = DateTimeFactory.nowUtc();
    for (final scope in scopes) {
      await _database
          .into(_database.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId.storageKey,
              trackId: trackId,
              scopeLevel: scope.level,
              scopeValue: scope.value,
              createdAt: now,
            ),
          );
    }
  }

  Future<void> _seedPointConfigsIfNeeded({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
  }) async {
    final profile = await _database.profileDao.getProfileById(profileId);
    if (profile?.mode != 'child') return;

    final existing = await _database.pointConfigDao.getConfigsByCurriculum(
      curriculumId.storageKey,
      profileId: profileId,
      trackId: trackId,
    );
    if (existing.isEmpty) {
      await _database.pointConfigDao.seedDefaults(
        curriculumId.storageKey,
        trackId,
        profileId: profileId,
      );
    }
  }
}
