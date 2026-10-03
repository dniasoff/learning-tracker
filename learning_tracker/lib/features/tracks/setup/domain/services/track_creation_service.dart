import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';

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
/// every write here is keyed on [CurriculumId] alone.
///
/// ## One named governed action (DNI-476 AC-5, AD-38)
///
/// The track, its stages, study days, scope, program enrolment and goal are
/// written as ONE owner action through [AddTrackActionRepository]: one
/// change-log entry per entity, all sharing one `action_id`, each entity in
/// its own self-contained batch of at most 10 governed docs, in action
/// order, with a retry re-sending the identical batch (same ids).
///
/// Adding a curriculum whose track was removed re-adds it (AD-38, ruling
/// B13): `ended_at` is cleared and the prior config is kept, so the flow's
/// own config (and the program's starting reference) is not applied — see
/// [AddTrackActionRepository.applyAddTrack].
///
/// The program's starting reference is the governed `tracking_start_ref`;
/// the post-success `logTrackAdded` analytics event follows only once the
/// track is confirmed (deferred for an action queued offline, see
/// [createTrack]).
class TrackCreationService {
  TrackCreationService({
    required AddTrackActionRepository actionRepository,
    required LearningProcessWizardService wizardService,
    AnalyticsService? analytics,
    bool Function() isTutoredSession = _ownerSession,
  }) : _actionRepository = actionRepository,
       _wizardService = wizardService,
       _analytics = analytics ?? const NullAnalyticsService(),
       _isTutoredSession = isTutoredSession;

  static bool _ownerSession() => false;

  final AddTrackActionRepository _actionRepository;
  final LearningProcessWizardService _wizardService;
  final AnalyticsService _analytics;
  final bool Function() _isTutoredSession;

  /// Persist all track configuration from the AddTrackFlow result as one
  /// governed action.
  ///
  /// The `logTrackAdded` event runs only once the track is confirmed: right
  /// away for a saved action, and for an action queued offline once the
  /// server accepts it — never if it refuses it (AD-54: the refused action
  /// is rolled back and surfaces as a pending failure), so no analytics
  /// event outlives a track that was never added.
  Future<void> createTrack({required AddTrackResult result}) async {
    if (_isTutoredSession()) {
      throw const TutorTrackCreationUnsupportedException();
    }
    final plan = planFor(result);
    final outcome = await _actionRepository.applyAddTrack(plan);
    if (!outcome.queued) {
      await _afterTrackAdded(result);
      return;
    }
    AppLogger.instance.info(
      event:
          'TrackCreationService: track for '
          '${result.curriculumId.storageKey} queued offline',
    );
    unawaited(_afterConfirmed(result, outcome));
  }

  Future<void> _afterConfirmed(
    AddTrackResult result,
    AddTrackOutcome outcome,
  ) async {
    if (!await outcome.whenConfirmed()) {
      AppLogger.instance.warning(
        event: 'track_creation_queued_action_not_confirmed',
        fields: {'curriculum_id': result.curriculumId.storageKey},
      );
      return;
    }
    try {
      await _afterTrackAdded(result);
    } on Object catch (error, stackTrace) {
      AppLogger.instance.warning(
        event: 'track_creation_deferred_follow_up_failed',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': result.curriculumId.storageKey},
      );
    }
  }

  /// The analytics follow-up of a confirmed Add track action.
  Future<void> _afterTrackAdded(AddTrackResult result) async {
    AppLogger.instance.info(
      event:
          'TrackCreationService: track "${result.label}" created for '
          '${result.curriculumId.storageKey}',
    );

    // Story 27.14 (DNI-390): fire analytics event after successful track creation.
    unawaited(
      _analytics.logTrackAdded(curriculumId: result.curriculumId.storageKey),
    );
  }

  /// The [AddTrackPlan] [result] describes.
  ///
  /// * Stages come from the learning-process (chazara) wizard; when the
  ///   flow skipped it, a לימוד-only ("no review") set — every track MUST
  ///   carry at least the primary learning stage (the scheduler skips a
  ///   stage-less track).
  /// * A goal without a description falls back to [AddTrackResult.label].
  @visibleForTesting
  AddTrackPlan planFor(AddTrackResult result) {
    final curriculum = result.curriculumId;
    final (:trackingStartRef, :trackingStartDate) = result.programId == null
        ? (trackingStartRef: null, trackingStartDate: null)
        : _parseProgramStartingRef(result.startingRef);
    final wizardResult =
        result.wizardResult?.wizardResult ??
        WizardResult(curriculumId: curriculum, choice: WizardChoice.noReview);
    final goal = result.goalResult;
    return AddTrackPlan(
      curriculumId: curriculum,
      stages: _wizardService.buildStages(wizardResult),
      studyDays: result.studyDays.map(
        (day, type) =>
            MapEntry(day, type == 'study' ? DayType.study : DayType.review),
      ),
      scopes: [
        for (final scope in result.scopeSelections ?? const <ScopeEntry>[])
          (level: scope.level, value: scope.value),
      ],
      program: result.programId == null
          ? null
          : AddTrackProgram(
              programId: result.programId!,
              trackingStartDate: trackingStartDate,
              trackingStartRef: trackingStartRef,
            ),
      goal: goal == null
          ? null
          : goal.copyWith(
              curriculumId: curriculum,
              description: goal.description.isNotEmpty
                  ? goal.description
                  : result.label,
            ),
    );
  }

  /// Parse the raw startingRef string into a governed tracking start and date.
  ///
  /// The format may be:
  ///   - null → start from beginning
  ///   - "offset:N|ref:<sefariaRef>" → calendar offset + resolved unit
  ///   - "offset:N" → legacy day-offset format
  ///   - a sefariaRef string (e.g. "Berakhot 42a") → content-based position
  ({String? trackingStartRef, DateTime? trackingStartDate})
  _parseProgramStartingRef(String? rawStartingRef) {
    var trackingStartRef = rawStartingRef;
    String? offsetToken;

    if (rawStartingRef != null && rawStartingRef.contains('|')) {
      for (final token in rawStartingRef.split('|')) {
        if (token.startsWith('offset:')) offsetToken = token;
        if (token.startsWith('ref:')) {
          final parsedRef = token.substring('ref:'.length);
          if (parsedRef.isNotEmpty) {
            trackingStartRef = parsedRef;
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

    return (
      trackingStartRef: trackingStartRef,
      trackingStartDate: trackingStartDate,
    );
  }
}

/// A tutor cannot use the owner-only Add track path until a governed add-track
/// callable exists. Refusal occurs before any action is prepared or written.
final class TutorTrackCreationUnsupportedException implements Exception {
  /// Creates the exception.
  const TutorTrackCreationUnsupportedException();

  @override
  String toString() => 'Add track is not available in a tutored session';
}
