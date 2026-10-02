/// Shared rig for the Story 2.4 (DNI-495) sub-track hub and form tests.
///
/// It wires the REAL Story 2.1 `SubTrackCommands` over the C0 in-memory
/// ports (`InMemorySubTrackRepository`, `InMemoryGovernedIntentRepository`),
/// so a save runs the shared AD-45 validation and lands in the same store
/// the hub reads — including offline latency compensation and a permanent
/// sync rejection that reverts the row (`InMemorySubTrackRepository.offline`
/// / `failNextWith` / `settleHeld`). The learner state is a tiny stand-in
/// engine derived live from that store, so the daily target visibly
/// recomputes after a save (Story 2.3 is consumed through the C0 contract).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';

import '../learner_state/c0_fixtures.dart';
import '../learner_state/fake_learner_state.dart';
import '../learner_state/fake_learning_commands.dart';
import '../learner_state/in_memory_ports.dart';
import '../learner_state_fixtures.dart';

/// The curriculum every sub-track test uses (leaf unit: Mishnayos).
const subTrackTestCurriculum = 'mishnayos';

/// "Today" in every sub-track test: academic year 2026.
const subTrackTestToday = '2026-10-02';

/// A stored school-year sub-track of [subTrackTestCurriculum].
SubTrack storedSchoolYear(
  String id, {
  String name = 'School',
  int academicYear = 2026,
  String? windowStart,
  String? windowEnd,
  double rate = 10,
  double weeks = 39,
  bool ended = false,
  String curriculumId = subTrackTestCurriculum,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: name,
  type: SubTrackType.schoolYear,
  academicYear: academicYear,
  windowStart: windowStart ?? '$academicYear-09-01',
  windowEnd: windowEnd ?? '${academicYear + 1}-07-31',
  ratePerWeek: rate,
  weeksPerYear: weeks,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: ulidE,
  endedAt: ended ? t1 : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

/// A stored ongoing sub-track of [subTrackTestCurriculum].
SubTrack storedOngoing(String id, {String name = 'Rebbe', double rate = 5}) =>
    SubTrack(
      id: id,
      curriculumId: subTrackTestCurriculum,
      name: name,
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: rate,
      weeksPerYear: 40,
      learnsOnShabbos: false,
      ground: const [],
      lastChangeId: ulidE,
    );

/// [LearningCommands] whose sub-track commands run the real Story 2.1
/// [SubTrackCommands]; every other command is a recording fake.
///
/// The real commands run in the root zone (real timers and stream
/// cancellation, as in production), so a widget test that taps *Save*
/// waits for them with [settleCommands] (`tester.runAsync`), not with
/// fake-time pumps alone.
final class SubTrackBackedLearningCommands implements LearningCommands {
  SubTrackBackedLearningCommands(this.subTracks);

  /// The real sub-track commands.
  final SubTrackCommands subTracks;

  final _fake = FakeLearningCommands();

  /// Every `createSubTrack` draft, in order.
  final List<SubTrackDraft> creates = [];

  /// Every `editSubTrack` call, in order.
  final List<(String, SubTrackEdit)> edits = [];

  /// When set, the next sub-track command returns it instead of running
  /// (one-shot).
  CaptureResult? nextResult;

  /// When set, the next sub-track command throws it (one-shot).
  Object? nextError;

  Future<CaptureResult>? _scripted() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      return Future.error(error);
    }
    final result = nextResult;
    if (result != null) {
      nextResult = null;
      return Future.value(result);
    }
    return null;
  }

  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
  }) {
    creates.add(draft);
    return _scripted() ??
        Zone.root.run(
          () => subTracks.createSubTrack(draft, subTrackId: subTrackId),
        );
  }

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) {
    edits.add((subTrackId, edit));
    return _scripted() ??
        Zone.root.run(() => subTracks.editSubTrack(subTrackId, edit));
  }

  @override
  Future<CaptureResult> endSubTrack(String subTrackId) =>
      subTracks.endSubTrack(subTrackId);

  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      subTracks.deleteSubTrack(subTrackId);

  @override
  Stream<List<PendingFailure>> watchPendingFailures() =>
      subTracks.watchPendingFailures();

  @override
  Future<CaptureResult> retry(String pendingFailureId) =>
      subTracks.retry(pendingFailureId);

  @override
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
  }) => _fake.capture(
    curriculumId: curriculumId,
    refs: refs,
    nodes: nodes,
    source: source,
    dateState: dateState,
    learnedOn: learnedOn,
    stage: stage,
  );

  @override
  Future<CaptureResult> voidEvent(String targetId) => _fake.voidEvent(targetId);

  @override
  Future<CaptureResult> replace(
    String targetId,
    EventReplacement replacement,
  ) => _fake.replace(targetId, replacement);

  @override
  Future<CaptureResult> unlearn(String curriculumId, Set<LeafRef> leafSet) =>
      _fake.unlearn(curriculumId, leafSet);

  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) =>
      _fake.undoEvents(eventIds);

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) =>
      _fake.applyGovernedChange(action);

  @override
  Future<CaptureResult> undoAction(String actionId) =>
      _fake.undoAction(actionId);
}

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _AshkenaziVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

/// The stand-in daily target: 30 minus the live school-year rates of the
/// curriculum (floored at 1) — just enough arithmetic for a save to move
/// it. The real AD-44 arithmetic is Story 2.3's.
int standInDailyTarget(Iterable<SubTrack> tracks) {
  final rates = tracks
      .where((t) => t.curriculumId == subTrackTestCurriculum && !t.isEnded)
      .fold<double>(0, (sum, t) => sum + t.ratePerWeek);
  final target = 30 - rates.round();
  return target < 1 ? 1 : target;
}

/// One rig per test.
final class SubTrackHarness {
  SubTrackHarness({
    this.today = subTrackTestToday,
    this.deadline,
    this.calendarProgramId,
    this.studyDaysPerWeek = 5,
    Iterable<SubTrack> seed = const [],
  }) {
    repo.seed(scope, seed);
    intent.emit(scope, _intent());
    commands = SubTrackBackedLearningCommands(
      SubTrackCommands(
        scope: scope,
        actor: parentActor,
        subTracks: repo,
        intent: intent,
        today: () => today,
        nowUtc: () => DateTime.utc(2026, 10, 2, 9),
        newId: _ids(),
        ackTimeout: const Duration(milliseconds: 50),
        readTimeout: const Duration(seconds: 2),
      ),
    );
  }

  /// The learner scope.
  final LearnerScope scope = c0Scope();

  /// The learner's civil today.
  final CivilDate today;

  /// The deadline goal's target date, if any.
  final CivilDate? deadline;

  /// The curriculum's calendar program, if any.
  final String? calendarProgramId;

  /// The curriculum's study days per week (per-school-day helper).
  final int studyDaysPerWeek;

  /// The sub-track store.
  final repo = InMemorySubTrackRepository();

  /// The governed intent store.
  final intent = InMemoryGovernedIntentRepository();

  /// The commands the form calls.
  late final SubTrackBackedLearningCommands commands;

  /// Every sub-track currently in the store.
  Future<List<SubTrack>> stored() async {
    final read = await repo
        .watchAll(scope)
        .firstWhere((r) => r is CompleteReadReady<SubTrack>);
    return (read as CompleteReadReady<SubTrack>).items;
  }

  LearnerIntent _intent() => LearnerIntent(
    settings: c0Settings,
    mainTracks: {
      subTrackTestCurriculum: MainTrackIntent(
        curriculumId: subTrackTestCurriculum,
        track: MainTrack(
          curriculumId: subTrackTestCurriculum,
          state: MainTrackState.active,
        ),
        program: calendarProgramId == null
            ? null
            : MainTrackProgram(
                curriculumId: subTrackTestCurriculum,
                programId: calendarProgramId,
                trackingStartDate: '2026-01-01',
              ),
      ),
    },
    goals: {
      if (deadline case final target?)
        subTrackTestCurriculum: CurriculumGoals(
          deadline: DeadlineGoal(
            curriculumId: subTrackTestCurriculum,
            targetDate: target,
          ),
        ),
    },
  );

  /// The provider overrides for this rig. [parentSession] is the AC-3
  /// session answer (null leaves the session provider to the caller);
  /// [commands] and [subTrackRepository] false leave those providers to the
  /// caller too (a container may override a provider only once).
  List<Override> overrides({
    bool? parentSession = true,
    bool commands = true,
    bool subTrackRepository = true,
  }) => [
    activeLearnerScopeProvider.overrideWith((ref) async => scope),
    if (subTrackRepository)
      subTrackRepositoryProvider.overrideWith((ref) async => repo),
    governedIntentRepositoryProvider.overrideWith((ref) async => intent),
    if (commands)
      learningCommandsProvider.overrideWith((ref) async => this.commands),
    learnerStateProvider.overrideWith(
      (ref, scope) => repo
          .watchAll(scope)
          .where((r) => r is CompleteReadReady<SubTrack>)
          .map(
            (r) => fakeLearnerState(
              curricula: {
                subTrackTestCurriculum: FakeCurriculumState(
                  curriculumId: subTrackTestCurriculum,
                  dailyTarget: deadline == null
                      ? null
                      : standInDailyTarget(
                          (r as CompleteReadReady<SubTrack>).items,
                        ),
                ),
              },
            ),
          ),
    ),
    if (parentSession case final session?)
      subTrackParentSessionProvider.overrideWith((ref) async => session),
    subTrackTodayProvider.overrideWithValue(today),
    studyDaysPerWeekProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => studyDaysPerWeek),
    useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
    currentTransliterationVariantProvider.overrideWith(_AshkenaziVariant.new),
    currentAppLocaleProvider.overrideWithValue(const Locale('en')),
  ];

  /// Closes the stores.
  Future<void> dispose() async {
    await commands.subTracks.dispose();
    await repo.dispose();
    await intent.dispose();
  }
}

/// `01JHARN…` + a counter: valid, distinct, ascending ULIDs.
String Function() _ids() {
  var n = 0;
  return () => '01JHARN00000000000000${(++n).toString().padLeft(5, '0')}';
}

/// Lets the real (root-zone) sub-track commands finish — past their 50 ms
/// ack window — then settles the frames.
Future<void> settleCommands(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
  }
}
