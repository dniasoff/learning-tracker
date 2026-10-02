/// The pure learner-state engine (AD-35):
/// `const LearnerStateEngine().run(LearnerStateInputs(...)) → LearnerState`.
///
/// The engine is an ordered pipeline of pure stage functions, one file per
/// stage, and [DerivedCurriculumState] is composed of per-stage records:
///
/// 1. counted events (`counted_events.dart`; lock hook filled by DNI-466);
/// 2. learnt set and scope (DNI-465);
/// 3. tri-state and main-track position (DNI-465; order and held ground
///    by DNI-467);
/// 4. completed units (DNI-465);
/// 5. planning, streak, points (DNI-466, 467, 468).
///
/// No I/O, clock read or global state: every input is in
/// [LearnerStateInputs], and identical inputs give equal outputs.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/derived_curriculum_state.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// One calendar program assignment: [node] is assigned on [date].
final class CalendarAssignment {
  /// Creates an assignment.
  const CalendarAssignment(this.date, this.node);

  /// The civil date.
  final CivilDate date;

  /// The assigned node.
  final NodeEntry node;

  @override
  bool operator ==(Object other) =>
      other is CalendarAssignment && other.date == date && other.node == node;

  @override
  int get hashCode => Object.hash(date, node);

  @override
  String toString() => 'CalendarAssignment($date, $node)';
}

/// The complete inputs of one engine run (AD-35 "Complete inputs").
final class LearnerStateInputs {
  /// Creates the inputs.
  const LearnerStateInputs({
    required this.events,
    required this.subTracks,
    required this.mainTrackIntent,
    required this.goals,
    required this.intentHistory,
    required this.settingsHistory,
    required this.calendars,
    required this.corpora,
    required this.nowUtc,
  });

  /// Every learning event (complete).
  final List<LearningEvent> events;

  /// Every sub-track, live and tombstoned.
  final List<SubTrack> subTracks;

  /// Main-track intent by curriculum id.
  final Map<String, MainTrackIntent> mainTrackIntent;

  /// Goals by curriculum id.
  final Map<String, CurriculumGoals> goals;

  /// The governed intent change history (AD-37).
  final List<ChangeLogEntry> intentHistory;

  /// The learnerSettings slice of [intentHistory], reconstructed.
  final LearnerSettingsHistory settingsHistory;

  /// Calendar program assignments by `program_id`.
  final Map<String, List<CalendarAssignment>> calendars;

  /// Unscoped corpora by curriculum id.
  final Map<String, Corpus> corpora;

  /// The instant to evaluate at (UTC).
  final DateTime nowUtc;
}

/// The pure learner-state engine.
final class LearnerStateEngine {
  /// The engine has no state.
  const LearnerStateEngine();

  /// Folds [inputs] into a [LearnerState].
  ///
  /// Every curriculum named by a corpus, a main-track intent or a `learn`
  /// event gets a [CurriculumState]. Only a curriculum whose
  /// `curriculum_tracks` doc is `active` with no `ended_at` (and whose
  /// corpus is present) is `evaluated` and gets position and plan; events
  /// of every curriculum still count for the learnt set and siyum (AD-35).
  LearnerState run(LearnerStateInputs inputs) {
    final counted = countEvents(
      inputs.events,
      isLockIgnored: _lockIgnoreHook(inputs),
    );
    final curricula = <String>{
      ...inputs.corpora.keys,
      ...inputs.mainTrackIntent.keys,
      for (final e in counted.learns) e.curriculumId!,
    }.toList()..sort();
    return LearnerState(
      nowUtc: inputs.nowUtc,
      curricula: {
        for (final c in curricula) c: _curriculum(c, inputs, counted),
      },
      countedEventIds: counted.countedIds,
      lockIgnoredEventIds: counted.lockIgnoredIds,
    );
  }

  /// The AD-36 lock-ignore rule. DNI-466 (1.4) replaces this with the
  /// lock-window rule over `inputs.settingsHistory`.
  LockIgnoreHook _lockIgnoreHook(LearnerStateInputs inputs) => noLockIgnored;

  DerivedCurriculumState _curriculum(
    String curriculumId,
    LearnerStateInputs inputs,
    CountedEvents counted,
  ) {
    final corpus = inputs.corpora[curriculumId];
    final intent = inputs.mainTrackIntent[curriculumId];
    final evaluated = corpus != null && intent != null && intent.isEvaluated;
    return DerivedCurriculumState(
      curriculumId: curriculumId,
      evaluated: evaluated,
      learnt: LearntRecord.none(),
    );
  }
}
