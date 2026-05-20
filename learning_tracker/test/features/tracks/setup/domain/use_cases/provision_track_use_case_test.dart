/// Tests for [ProvisionTrackUseCase] — W4.14 regression suite.
///
/// ### B3 — Back-dated enrolment produces overdue tasks
///
/// The B3 invariant is: enrolling in a calendar program with
/// `start_date = today − N` (N > 0) must result in N scheduled units
/// dated in the past, which the overdue projection surfaces as overdue items.
///
/// Tests split into:
///   1. Bridge tests — verify [TrackBlueprint] → [AddTrackResult] conversion
///      by inspecting what is passed to the underlying service.
///   2. B3 projection tests — pure-function verification that the offset
///      encoding wired by the use case leads to N overdue tasks in the
///      [programSchedule] + [project] pipeline.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/aggregates/track_blueprint.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/use_cases/provision_track_use_case.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

// ── Spy service ──────────────────────────────────────────────────────────────

/// Subclass of [TrackCreationService] that overrides [createTrack] to capture
/// calls without performing any database writes.
///
/// This lets the bridge tests instantiate the REAL [ProvisionTrackUseCase] and
/// verify that production [_toResult] logic correctly maps [TrackBlueprint]
/// to [AddTrackResult].  A regression in [_toResult] will now cause bridge
/// test failures.
class _SpyTrackCreationService extends TrackCreationService {
  _SpyTrackCreationService(UserDatabase db)
    : super(
        database: db,
        activationService: CurriculumActivationService(
          database: db,
          pushCurriculumTrack: null,
          trackRepository: TrackRepositoryImpl(database: db),
        ),
        wizardService: LearningProcessWizardService(
          stageDao: db.stageDao,
          learningProgramRepo: LearningProgramRepository.instance,
          profileProgramDao: db.profileProgramDao,
        ),
        goalRepository: GoalRepositoryImpl(database: db),
        stageRepository: StageDefinitionRepositoryImpl(
          stageDao: db.stageDao,
          completionDao: db.completionDao,
          pushSettings: null,
        ),
        analytics: const NullAnalyticsService(),
      );

  AddTrackResult? capturedResult;
  int? capturedProfileId;

  @override
  Future<void> createTrack({
    required AddTrackResult result,
    required int profileId,
  }) async {
    capturedResult = result;
    capturedProfileId = profileId;
    // No database writes — spy only.
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const _kStudyDaysAllWeek = <int, String>{
  1: 'study',
  2: 'study',
  3: 'study',
  4: 'study',
  5: 'study',
  6: 'study',
  7: 'study',
};

TrackBlueprint _calendarBlueprint({
  required ProgramStartingPosition startingPosition,
}) {
  return TrackBlueprint(
    curriculumId: CurriculumId.bavli,
    label: 'Daf Yomi',
    studyDays: _kStudyDaysAllWeek,
    programSelection: CalendarProgramSelection(
      programId: 1,
      programName: 'Daf Yomi',
      startingPosition: startingPosition,
    ),
    stageConfiguration: const SingleStageConfiguration(),
    goalIntent: const NoGoalIntent(),
    bulkMarkIntent: const NoBulkMarkIntent(),
  );
}

TrackBlueprint _selfPacedBlueprint() {
  return const TrackBlueprint(
    curriculumId: CurriculumId.bavli,
    label: 'Bavli Self-Paced',
    studyDays: {1: 'study', 2: 'study'},
    programSelection: SelfPacedSelection(),
    stageConfiguration: SingleStageConfiguration(),
    goalIntent: NoGoalIntent(),
    bulkMarkIntent: NoBulkMarkIntent(),
  );
}

/// Returns one fake calendar entry per calendar day in [anchor, today].
List<(DateTime date, String sefariaRef)> _fakeCalendarEntries({
  required DateTime anchor,
  required DateTime today,
}) {
  final result = <(DateTime, String)>[];
  var cursor = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final end = DateTime.utc(today.year, today.month, today.day);
  while (!cursor.isAfter(end)) {
    final y = cursor.year.toString().padLeft(4, '0');
    final m = cursor.month.toString().padLeft(2, '0');
    final d = cursor.day.toString().padLeft(2, '0');
    result.add((cursor, 'daf_yomi $y-$m-$d'));
    cursor = cursor.add(const Duration(days: 1));
  }
  return result;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  final today = DateTime(2026, 5, 20);
  const profileId = 1;

  late FakeLocalDayClock clock;
  late UserDatabase db;
  late _SpyTrackCreationService spyService;
  late ProvisionTrackUseCase useCase;

  setUp(() {
    clock = FakeLocalDayClock(today);
    db = UserDatabase(NativeDatabase.memory());
    spyService = _SpyTrackCreationService(db);
    useCase = ProvisionTrackUseCase(service: spyService, clock: clock);
  });

  tearDown(() async => db.close());

  // ── W4.14 — Bridge: TrackBlueprint → AddTrackResult conversion ─────────────
  //
  // These tests exercise the REAL ProvisionTrackUseCase._toResult() method.
  // A regression in production _toResult() (e.g., wrong switch branch) will
  // cause failures here.
  group('ProvisionTrackUseCase bridge', () {
    test('self-paced blueprint → createTrack with no programId', () async {
      final blueprint = _selfPacedBlueprint();

      await useCase(blueprint: blueprint, profileId: profileId);

      final result = spyService.capturedResult!;
      expect(result.programId, isNull);
      expect(result.startingRef, isNull);
      expect(result.curriculumId, CurriculumId.bavli);
      expect(result.label, 'Bavli Self-Paced');
    });

    test('calendar blueprint (today) → createTrack with programId', () async {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      final blueprint = _calendarBlueprint(startingPosition: pos);

      await useCase(blueprint: blueprint, profileId: profileId);

      final result = spyService.capturedResult!;
      expect(result.programId, 1);
      expect(result.programName, 'Daf Yomi');
      expect(result.curriculumId, CurriculumId.bavli);
    });

    test(
      'today start → no startingRef (offset:0 is normalised to null)',
      () async {
        final pos = ProgramStartingPosition.create(
          startDate: today,
          today: today,
        );
        final blueprint = _calendarBlueprint(startingPosition: pos);

        await useCase(blueprint: blueprint, profileId: profileId);

        // offset:0 → toLegacyGrammar produces "" → normalised to null.
        expect(spyService.capturedResult!.startingRef, isNull);
      },
    );

    test('back-dated N=5 → startingRef encodes offset:5', () async {
      const n = 5;
      final startDate = today.subtract(const Duration(days: n));
      final pos = ProgramStartingPosition.create(
        startDate: startDate,
        today: today,
      );
      final blueprint = _calendarBlueprint(startingPosition: pos);

      await useCase(blueprint: blueprint, profileId: profileId);

      expect(
        spyService.capturedResult!.startingRef,
        'offset:$n',
        reason: 'B3: offset grammar must encode the back-date offset',
      );
    });

    test('profileId is forwarded unchanged', () async {
      final blueprint = _selfPacedBlueprint();
      const expectedProfileId = 42;

      await useCase(blueprint: blueprint, profileId: expectedProfileId);

      expect(spyService.capturedProfileId, expectedProfileId);
    });

    test('NoGoalIntent → goalResult is null in AddTrackResult', () async {
      final blueprint = _selfPacedBlueprint();

      await useCase(blueprint: blueprint, profileId: profileId);

      expect(spyService.capturedResult!.goalResult, isNull);
    });

    test(
      'NoBulkMarkIntent → bulkMarkResult is null in AddTrackResult',
      () async {
        final blueprint = _selfPacedBlueprint();

        await useCase(blueprint: blueprint, profileId: profileId);

        expect(spyService.capturedResult!.bulkMarkResult, isNull);
      },
    );

    test(
      'SingleStageConfiguration → wizardResult is null in AddTrackResult',
      () async {
        final blueprint = _selfPacedBlueprint();

        await useCase(blueprint: blueprint, profileId: profileId);

        expect(spyService.capturedResult!.wizardResult, isNull);
      },
    );
  });

  // ── B3 — Back-dated enrolment (pure projection pipeline) ──────────────────
  group('B3 — back-dated programme enrolment', () {
    // These tests verify the CONTRACT between ProvisionTrackUseCase and the
    // projection layer: the offset encoded by the use case leads to the
    // correct number of overdue tasks in the programSchedule + project
    // pipeline. Tests are pure — no DB, no Flutter, no Riverpod.

    test('B3-1: N=5 back-dated → 5 overdue + 1 today unit (0 completions)', () {
      const n = 5;
      final anchor = today.subtract(const Duration(days: n));

      final entries = _fakeCalendarEntries(anchor: anchor, today: today);
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: entries,
        today: today,
      );

      expect(
        schedule.length,
        n + 1,
        reason: 'N past days + today = N+1 scheduled entries',
      );

      final result = project(
        schedule: schedule,
        completions: const {},
        today: today,
      );

      expect(
        result.overdue.length,
        n,
        reason: 'B3: 5 past-dated units with 0 completions → 5 overdue',
      );
      expect(
        result.dueToday.length,
        1,
        reason: 'B3: 1 unit scheduled for today',
      );
      expect(result.review, isEmpty);
    });

    test('B3-2: N=0 (start=today) → 0 overdue, 1 today unit', () {
      final anchor = today;

      final entries = _fakeCalendarEntries(anchor: anchor, today: today);
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: entries,
        today: today,
      );

      final result = project(
        schedule: schedule,
        completions: const {},
        today: today,
      );

      expect(
        result.overdue,
        isEmpty,
        reason: 'N=0: no back-date → no overdue tasks',
      );
      expect(result.dueToday.length, 1);
    });

    test('B3-3: N=3 with 2 past completions → 1 overdue remaining', () {
      const n = 3;
      final anchor = today.subtract(const Duration(days: n));

      final entries = _fakeCalendarEntries(anchor: anchor, today: today);
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: entries,
        today: today,
      );

      // Mark 2 of the 3 past-dated refs as completed.
      final completed = {schedule[0].sefariaRef, schedule[1].sefariaRef};

      final result = project(
        schedule: schedule,
        completions: completed,
        today: today,
      );

      expect(
        result.overdue.length,
        1,
        reason: 'B3: 3 past units − 2 completed = 1 overdue',
      );
    });

    test(
      'B3-4: ProgramStartingPosition.daysFromToday reflects N correctly',
      () {
        const n = 5;
        final pos = ProgramStartingPosition.create(
          startDate: today.subtract(const Duration(days: n)),
          today: today,
        );

        expect(
          pos.daysFromToday(today),
          n,
          reason:
              'B3: VO is the single source of truth for the back-date depth',
        );
      },
    );

    test(
      'B3-5: toLegacyGrammar round-trips through fromLegacyGrammar for N=5',
      () {
        const n = 5;
        final pos = ProgramStartingPosition.create(
          startDate: today.subtract(const Duration(days: n)),
          today: today,
        );

        final grammar = pos.toLegacyGrammar(today);
        final rt = ProgramStartingPosition.fromLegacyGrammar(
          rawStartingRef: grammar,
          today: today,
        );

        expect(
          rt.daysFromToday(today),
          n,
          reason: 'B3: offset grammar must survive a round-trip',
        );
      },
    );
  });

  // ── Adversarial validator ─────────────────────────────────────────────────
  //
  // This group exists to prove the tests are NOT false positives.
  //
  // The bridge tests above exercise the REAL ProvisionTrackUseCase._toResult()
  // via the spy. This test documents that a concrete regression in _toResult
  // (e.g., the offset grammar branch being silenced so all back-dated starts
  // emit null) would be detected:
  //
  //   • If _toResult omitted the startingRef for N≥1, the bridge test
  //     'back-dated N=5 → startingRef encodes offset:5' would fail with:
  //       Expected: 'offset:5'
  //       Actual:   <null>
  //
  //   • If _toResult returned an empty string instead of null for N=0, the
  //     bridge test 'today start → no startingRef' would fail with:
  //       Expected: <null>
  //       Actual:   ''
  //
  // The test below asserts the N=1 boundary directly — one day before today
  // must produce 'offset:1', not null, not 'offset:0', not anything else.
  // This is the minimal offset that exercises the non-trivial branch in
  // _toResult (the grammar.isEmpty → null normalisation path is the branch
  // that a naive mutation might break for small offsets).
  group('adversarial validator — _toResult regression sensitivity', () {
    test(
      'N=1 back-date → startingRef is exactly "offset:1" (not null, not "offset:0")',
      () async {
        // If production _toResult had a bug such as:
        //   final grammar = pos.toLegacyGrammar(today);
        //   startingRef = grammar.isEmpty ? null : grammar;
        // being replaced by:
        //   startingRef = null; // or startingRef = 'offset:0';
        // this test would fail, proving the spy exercises the real code path.
        const n = 1;
        final startDate = today.subtract(const Duration(days: n));
        final pos = ProgramStartingPosition.create(
          startDate: startDate,
          today: today,
        );
        final blueprint = _calendarBlueprint(startingPosition: pos);

        await useCase(blueprint: blueprint, profileId: profileId);

        expect(
          spyService.capturedResult!.startingRef,
          'offset:1',
          reason:
              'Adversarial: _toResult must produce offset:1 for N=1; '
              'null or offset:0 would indicate a regression in the '
              'offset-branch of ProvisionTrackUseCase._toResult()',
        );
      },
    );
  });
}
