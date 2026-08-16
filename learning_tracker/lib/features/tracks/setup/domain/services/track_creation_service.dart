import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/curriculum_scope_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';

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

/// Creates a track from an [AddTrackResult].
///
/// AD-25: a track IS a curriculum (one track per curriculum per profile) —
/// every write here is keyed on [CurriculumId] alone, there is no separate
/// per-device track id to thread through or resolve.
///
/// Not atomic across the stage/study-day/scope/goal/program-enrolment
/// writes (Firestore has no cross-collection transaction reachable through
/// the plain repository calls this whole migration already uses elsewhere —
/// same disclosed trade-off as `TrackEditService`/`LearningProcessWizardService`).
class TrackCreationService {
  TrackCreationService({
    required CurriculumActivationService activationService,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
    required FirestoreCurriculumTrackRepositoryAdapter trackRepository,
    required StudyDayWriteRepository studyDayRepository,
    required CurriculumScopeWriteRepository scopeRepository,
    required ProfileProgramRepository profileProgramRepository,
    required BookmarkRepository bookmarkRepository,
    AnalyticsService? analytics,
  }) : _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository,
       _trackRepository = trackRepository,
       _studyDayRepository = studyDayRepository,
       _scopeRepository = scopeRepository,
       _profileProgramRepository = profileProgramRepository,
       _bookmarkRepository = bookmarkRepository,
       _analytics = analytics ?? const NullAnalyticsService();

  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;
  final FirestoreCurriculumTrackRepositoryAdapter _trackRepository;
  final StudyDayWriteRepository _studyDayRepository;
  final CurriculumScopeWriteRepository _scopeRepository;
  final ProfileProgramRepository _profileProgramRepository;
  // The SAME repository the rest of the app reads bookmarks through
  // (Firestore-backed, ULID-profile-keyed — see bookmark_providers.dart).
  final BookmarkRepository _bookmarkRepository;
  final AnalyticsService _analytics;

  /// Persist all track configuration from the AddTrackFlow result.
  Future<void> createTrack({required AddTrackResult result}) async {
    final curriculum = result.curriculumId;
    final (:bookmarkRef, :trackingStartDate) = result.programId == null
        ? (bookmarkRef: null, trackingStartDate: null)
        : _parseProgramStartingRef(result.startingRef);

    // Restore any soft-deleted/archived track (avoids a duplicate doc on
    // re-add) or create fresh — idempotent, matching the old restoreOrCreate.
    await _trackRepository.activateTrack(curriculum);

    // Stages are seeded from the learning-process (chazara) wizard. When the
    // add-track flow skipped that step (wizardResult == null — e.g. a track
    // created without configuring chazara), fall back to a לימוד-only
    // ("no review") configuration. Every track MUST carry at least the
    // primary learning stage: the scheduler's projection does
    // `if (stages.isEmpty) continue;`, so a stage-less track is skipped
    // entirely and the dashboard shows "No projection" / 0 due despite a
    // valid goal + computed pace. A noReview result seeds ONLY the learn
    // stage — no chazara rounds — honouring the per-track chazara rule.
    // applyWizardResult overwrites the curriculum's whole stage set in place.
    final wizardResult =
        result.wizardResult?.wizardResult ??
        WizardResult(curriculumId: curriculum, choice: WizardChoice.noReview);
    await _wizardService.applyWizardResult(wizardResult);

    await _studyDayRepository.replaceAllForCurriculum(
      curriculumId: curriculum,
      studyDays: result.studyDays.map(
        (day, type) =>
            MapEntry(day, type == 'study' ? DayType.study : DayType.review),
      ),
    );

    await _scopeRepository.clearScopes(curriculum);
    if (result.scopeSelections != null && result.scopeSelections!.isNotEmpty) {
      await _scopeRepository.insertScopes(
        curriculumId: curriculum,
        scopes: [
          for (final scope in result.scopeSelections!)
            (level: scope.level, value: scope.value),
        ],
      );
    }

    // Point-config seeding (Drift's _seedPointConfigsIfNeeded) is
    // deliberately NOT translated here, or anywhere: point_configs is
    // configuration-shaped (D-E) — an absent override document truthfully
    // means "use FirestorePointConfigRepository.defaultPointsForStage's
    // ladder", so a track with no seeded point-config row is the correct,
    // intended steady state, not a gap to close. See that repository
    // class's doc comment ("nothing is ever seeded").

    // Program enrolment — set or clear.
    if (result.programId == null) {
      await _profileProgramRepository.removeProgram(curriculum);
    } else {
      await _profileProgramRepository.setProgram(
        curriculumId: curriculum,
        programId: result.programId!,
        trackingStartDate: trackingStartDate,
        trackingStartRef: bookmarkRef,
      );
      // The bookmark itself is a SEPARATE Firestore write (below) — not
      // part of setProgram's payload. `trackingStartRef` above is the
      // durable record of the chosen starting ref; it is not read as a
      // bookmark by anything.
      if (bookmarkRef != null && bookmarkRef.isNotEmpty) {
        await _bookmarkRepository.setBookmark(
          curriculumId: curriculum,
          sefariaRef: bookmarkRef,
        );
      }
    }

    // Activate the curriculum in active_curricula (idempotent) — kept as a
    // best-effort call matching the original's tolerance for "likely
    // already active".
    try {
      // profileId is provably unused (see activateForProfile's own doc
      // comment: "intentionally not used... the only honest behaviour is
      // to activate for the already-scoped active profile") — passed as 0.
      await _activationService.activateForProfile(curriculum, 0);
    } catch (_) {
      AppLogger.instance.debug(
        event:
            'TrackCreationService: curriculum ${curriculum.storageKey} '
            'activation skipped (likely already active)',
      );
    }

    await _deleteExistingGoals(curriculum);
    await _recreateGoal(result: result, curriculum: curriculum);

    AppLogger.instance.info(
      event:
          'TrackCreationService: track "${result.label}" created for '
          '${curriculum.storageKey}',
    );

    // Story 27.14 (DNI-390): fire analytics event after successful track creation.
    unawaited(_analytics.logTrackAdded(curriculumId: curriculum.storageKey));
  }

  /// Delete all existing goals for [curriculum], syncing tombstones so
  /// re-add does not stack duplicates.
  Future<void> _deleteExistingGoals(CurriculumId curriculum) async {
    final existingGoals = await _goalRepository.getGoals(curriculum);
    for (final g in existingGoals) {
      await _goalRepository.deleteGoal(g);
    }
  }

  /// Create the goal from [result] if one is present.
  ///
  /// Falls back to [result.label] as the goal description when the [GoalEntity]
  /// carries an empty description — this covers tracks created before B4 was
  /// fixed and any code path that does not seed [GoalEntity.description].
  Future<void> _recreateGoal({
    required AddTrackResult result,
    required CurriculumId curriculum,
  }) async {
    if (result.goalResult == null) return;
    final goal = result.goalResult!;
    final description = goal.description.isNotEmpty
        ? goal.description
        : result.label;
    await _goalRepository.createGoal(
      curriculumId: curriculum,
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
}
