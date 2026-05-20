import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/tracks/setup/domain/aggregates/track_blueprint.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';

/// Use-case layer façade over [TrackCreationService].
///
/// Accepts a typed [TrackBlueprint] aggregate (W4.12) and converts it to the
/// [AddTrackResult] legacy format for the underlying service. Once the service
/// itself is migrated to accept a [TrackBlueprint] directly, the bridge code
/// in [_toResult] can be removed.
///
/// ### B3 — Back-dated enrolment
/// When [blueprint.startingPosition.daysFromToday] > 0 the track's program
/// started in the past. The DB record written by [TrackCreationService]
/// carries [trackingStartDate] = start date, which the scheduler projection
/// reads as the "anchor" to walk [anchor, today] and surface past-dated
/// scheduled units as overdue. [ProvisionTrackUseCase] is the call-site owner
/// of B3 — it ensures the typed [ProgramStartingPosition] VO (not a raw
/// string) reaches the service and from there the DB.
///
/// ### Ownership of [LocalDayClock]
/// The use case reads "today" from [clock] so that integration tests can
/// inject a [FakeLocalDayClock] and assert B3 overdue-count invariants
/// without touching the system clock.
class ProvisionTrackUseCase {
  const ProvisionTrackUseCase({
    required TrackCreationService service,
    required LocalDayClock clock,
  }) : _service = service,
       _clock = clock;

  final TrackCreationService _service;
  final LocalDayClock _clock;

  /// Provision the track described by [blueprint] for [profileId].
  ///
  /// Converts the typed [TrackBlueprint] to the legacy [AddTrackResult] and
  /// delegates to [TrackCreationService.createTrack]. The [today] parameter
  /// from the clock is used to translate [ProgramStartingPosition] back into
  /// the legacy `offset:N|ref:...` grammar.
  Future<void> call({
    required TrackBlueprint blueprint,
    required int profileId,
  }) async {
    final result = _toResult(blueprint);
    await _service.createTrack(result: result, profileId: profileId);
  }

  // ── Bridge ─────────────────────────────────────────────────────────────────

  /// Convert a typed [TrackBlueprint] to the legacy [AddTrackResult].
  ///
  /// This bridge is intentionally thin — it exists only to keep the service
  /// compilable while the call-site migration from [AddTrackResult] to
  /// [TrackBlueprint] is in progress. Once complete, [TrackCreationService]
  /// will be updated to accept a [TrackBlueprint] directly and this method
  /// can be deleted.
  AddTrackResult _toResult(TrackBlueprint blueprint) {
    final today = _clock.today();

    // ── Program selection ───────────────────────────────────────────────────
    int? programId;
    String? programName;
    String? startingRef;

    switch (blueprint.programSelection) {
      case CalendarProgramSelection(
        programId: final pid,
        programName: final pname,
        startingPosition: final pos,
      ):
        programId = pid;
        programName = pname;
        // Re-encode the VO back to the legacy grammar for the service layer.
        // B3: the grammar encodes the offset so the service writes
        // trackingStartDate = today − offset to profile_programs.
        final grammar = pos.toLegacyGrammar(today);
        startingRef = grammar.isEmpty ? null : grammar;
      case SelfPacedSelection():
        break;
    }

    // ── Stage configuration ─────────────────────────────────────────────────
    final wizardResult = switch (blueprint.stageConfiguration) {
      WizardStageConfiguration(:final wizardResult) => wizardResult,
      SingleStageConfiguration() || ScheduleSpecConfiguration() => null,
    };

    // ── Goal intent ─────────────────────────────────────────────────────────
    final goalResult = switch (blueprint.goalIntent) {
      SpecifiedGoalIntent(:final goal) => goal,
      NoGoalIntent() => null,
    };

    // ── Bulk-mark intent ────────────────────────────────────────────────────
    final bulkMarkResult = switch (blueprint.bulkMarkIntent) {
      BulkMarkedIntent(:final itemCount, :final completionCount) =>
        BulkMarkIntent(itemCount: itemCount, completionCount: completionCount),
      NoBulkMarkIntent() => null,
    };

    return AddTrackResult(
      curriculumId: blueprint.curriculumId,
      label: blueprint.label,
      programId: programId,
      programName: programName,
      scopeSelections: blueprint.scopeSelections,
      studyDays: blueprint.studyDays,
      wizardResult: wizardResult,
      goalResult: goalResult,
      bulkMarkResult: bulkMarkResult,
      startingRef: startingRef,
    );
  }
}
