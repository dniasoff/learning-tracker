/// Fixtures for the Dashboard forecast surfaces (Story 2.11, DNI-502):
/// fake engine states and the provider overrides that feed them.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
// `Override` is part of Riverpod's public API but is only re-exported from
// `misc.dart` (same import as `test/helpers/pump_app.dart`).
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';

import '../learner_state/c0_fixtures.dart';
import '../learner_state/engine_fixtures.dart';
import '../learner_state/fake_learner_state.dart';

/// The Mishnayos curriculum storage key.
const forecastCurriculum = 'mishnayos';

/// A sub-track ULID for fixtures.
const schoolSubTrackId = '01J6Q2H4A8M7K3P9R5T6V8WXS1';

/// A second sub-track ULID for fixtures.
const rebbeSubTrackId = '01J6Q2H4A8M7K3P9R5T6V8WXR2';

/// A Mishnayos curriculum state with [projection], [dailyTarget], a
/// [streak] and [subTracks].
FakeCurriculumState forecastCurriculumState({
  String curriculumId = forecastCurriculum,
  Projection projection = const Projection(status: ProjectionStatus.tooEarly),
  int? dailyTarget,
  CurriculumStreak? streak,
  Map<String, SubTrackState> subTracks = const {},
  bool evaluated = true,
}) => FakeCurriculumState(
  curriculumId: curriculumId,
  evaluated: evaluated,
  projection: projection,
  dailyTarget: dailyTarget,
  streak: streak,
  subTracks: subTracks,
);

/// A learner state holding [curricula].
LearnerState forecastState(List<CurriculumState> curricula) =>
    fakeLearnerState(curricula: {for (final c in curricula) c.curriculumId: c});

/// A sub-track state with an FR-19 [shortfall] over [lastNode].
SubTrackState shortfallSubTrack({
  required String id,
  required String name,
  required int shortfall,
  NodeEntry? lastNode,
  String? windowEnd,
}) => SubTrackState(
  subTrackId: id,
  name: name,
  holdsGround: true,
  inForecast: true,
  onHome: true,
  capacity: 10,
  shortfall: shortfall,
  windowEnd: windowEnd,
  lastShortfallNode: shortfall > 0 ? lastNode : null,
);

/// A [SubTrackDetailOpener] as if the sub-track detail route (DNI-497) were
/// registered: every warning offers *View {name} →*, whose tap does
/// nothing.
VoidCallback? registeredDetailOpener(
  BuildContext context,
  ShortfallWarning warning,
) => () {};

/// Overrides for the forecast surfaces: the session role ([parent]), the
/// active scope, the learner state ([state], or each element of [states]
/// emitted through a broadcast controller) and the curriculum display
/// labels ([nodeLabels] by ref, else the raw ref, so no content database
/// is read).
///
/// [parentSession], when given, resolves the role in place of [parent]
/// (a never-completing future keeps the role unresolved).
///
/// [detailOpener] resolves *View {name} →*; the default
/// [registeredDetailOpener] stands in for an app that registers the
/// sub-track detail route, since these surfaces are pumped without a
/// router. Null keeps the production [subTrackDetailAction].
List<Override> forecastOverrides({
  bool parent = true,
  Future<bool>? parentSession,
  LearnerState? state,
  Stream<LearnerState>? states,
  Map<String, String> nodeLabels = const {},
  SubTrackDetailOpener? detailOpener = registeredDetailOpener,
}) => [
  if (detailOpener != null)
    subTrackDetailOpenerProvider.overrideWithValue(detailOpener),
  parentSessionProvider.overrideWith(
    (ref) => parentSession ?? Future.value(parent),
  ),
  // English units ("Mishnayos"); Hebrew terms have their own setting.
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
  activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
  if (state != null || states != null)
    learnerStateProvider.overrideWith(
      (ref, _) => states ?? Stream.value(state!),
    ),
  renderedDisplayForRefProvider.overrideWith(
    (ref, sefariaRef) async => nodeLabels[sefariaRef] ?? sefariaRef,
  ),
];

/// A controllable stream of learner states for recompute tests: one
/// subscriber (the engine-backed `learnerStateProvider`), buffered until
/// it listens, seeded with [initial].
final class LearnerStateFeed {
  /// Creates the feed with its first state.
  LearnerStateFeed(LearnerState initial) {
    _controller.add(initial);
  }

  final _controller = StreamController<LearnerState>();

  /// The stream to pass as `states`.
  Stream<LearnerState> get stream => _controller.stream;

  /// Emits [state] as a recompute.
  void emit(LearnerState state) => _controller.add(state);

  /// Closes the feed.
  Future<void> close() => _controller.close();
}

/// The ordinary weekday instant fixture events are recorded at
/// (Thursday 2026-10-08 10:00Z, outside any lock); `learned_on` carries
/// the day.
final forecastRecordedAt = DateTime.utc(2026, 10, 8, 10);

/// A dated main-track `learn` of [ref] on [learnedOn], recorded at
/// [recordedAt] (default [forecastRecordedAt]).
LearningEvent forecastLearn(
  int id,
  String ref,
  String learnedOn, {
  DateTime? recordedAt,
  DateState dateState = DateState.dated,
}) => engineLearn(
  id,
  ref,
  minutes: (recordedAt ?? forecastRecordedAt)
      .difference(DateTime.utc(2026, 9))
      .inMinutes,
  learnedOn: learnedOn,
  stage: 1,
  dateState: dateState,
);

/// The real engine's state at [nowUtc] for the Mishnayos fixture corpus
/// tracked from [trackingStartDate], with an optional [deadline] goal.
LearnerState engineForecastState({
  required DateTime nowUtc,
  required String trackingStartDate,
  List<LearningEvent> events = const [],
  String? deadline,
  List<SubTrack> subTracks = const [],
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    nowUtc: nowUtc,
    subTracks: subTracks,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: engineCurriculum,
          trackingStartDate: trackingStartDate,
        ),
        stages: [engineStage(1), engineStage(2)],
      ),
    },
    goals: {
      engineCurriculum: CurriculumGoals(
        deadline: deadline == null
            ? null
            : DeadlineGoal(
                curriculumId: engineCurriculum,
                targetDate: deadline,
              ),
      ),
    },
  ),
);
