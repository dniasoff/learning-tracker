/// Hermetic rig for the Story 3.2 (DNI-505) catch-up card provider,
/// widget and reactivity tests: a fixed learner clock, a fixed settings
/// history, replaying live sources for the learner state and the
/// `sub_tracks` read, and a planner that answers per date.
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

import '../learner_state_fixtures.dart';
import 'lock_fixtures.dart';

/// The learner every catch-up test views.
final catchUpScope = LearnerScope(
  ownerUid: 'owner-uid',
  profileId: profileUlid,
);

/// A second learner on the same device.
final catchUpOtherScope = LearnerScope(
  ownerUid: 'owner-uid',
  profileId: '01ARZ3NDEKTSV4RRFFQ69G5FB2',
);

/// New York, the fixtures' learner zone.
final catchUpZone = LearnerZone.of('America/New_York');

/// No-location fallback history: Shabbos 2026-10-10 locks Fri 12:00 to
/// Sun 01:00 and its card lasts through Monday 2026-10-12.
final catchUpHistory = constantHistory(newYorkNoLocation);

/// Sunday 2026-10-11 12:00 learner-local: the Shabbos card is pending.
final catchUpSunday = catchUpZone.at(DateTime.utc(2026, 10, 11), hour: 12);

/// The locked Shabbos of [catchUpHistory].
const catchUpShabbos = '2026-10-10';

/// A main-track planner task on [ref].
DailyTask plannedTask(
  String ref, {
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'Due today',
  stageName: '',
  trackLabel: 'Mishnayos',
);

/// A planner that answers [byDate] for each date (nothing for the rest).
CatchUpSequencePlanner fixedPlanner(Map<String, List<DailyTask>> byDate) =>
    (ref, dates) async => [for (final d in dates) byDate[d] ?? const []];

/// A live source that replays its latest value to each new listener.
final class LiveSource<T> {
  /// Creates the source holding [value].
  LiveSource(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast();

  /// The current value.
  T get value => _value;

  /// Emits [next] to every listener.
  set value(T next) {
    _value = next;
    _changes.add(next);
  }

  /// The latest value, then every change.
  Stream<T> stream() async* {
    yield _value;
    yield* _changes.stream;
  }

  /// Closes the source.
  Future<void> close() => _changes.close();
}

/// A live, grounded Mishnayos sub-track named [name].
SubTrack catchUpSubTrack(
  String id, {
  String name = 'Rebbe',
  bool learnsOnShabbos = true,
}) => SubTrack(
  id: id,
  curriculumId: 'mishnayos',
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: learnsOnShabbos,
  ground: const [NodeEntry(level: 'masechet', ref: 'Mishnah_Peah')],
  lastChangeId: ulidC,
);

/// The overrides of one device viewing [scope] (or, when given,
/// [scopeOf]'s answer each time the active scope is read, so a test can
/// switch learners by invalidating `activeLearnerScopeProvider`).
List<Override> catchUpOverrides({
  required Stream<LearnerState> Function(LearnerScope scope) states,
  Stream<List<SubTrack>> Function(LearnerScope scope)? subTracks,
  LearnerScope? scope,
  LearnerScope Function()? scopeOf,
  DateTime Function()? clock,
  LearnerSettingsHistory? history,
  CatchUpSequencePlanner? planner,
  void Function(CatchUpHistoryGap gap)? onGap,
}) => [
  activeLearnerScopeProvider.overrideWith(
    (ref) async => scopeOf?.call() ?? scope ?? catchUpScope,
  ),
  learnerStateProvider.overrideWith((ref, s) => states(s)),
  subTracksForScopeProvider.overrideWith(
    (ref, s) => subTracks?.call(s) ?? Stream.value(const <SubTrack>[]),
  ),
  erevSettingsHistoryProvider.overrideWith(
    (ref) async => history ?? catchUpHistory,
  ),
  learningCommandClockProvider.overrideWithValue(clock ?? () => catchUpSunday),
  catchUpSequencePlannerProvider.overrideWithValue(
    planner ??
        fixedPlanner({
          catchUpShabbos: [plannedTask('Mishnah Berakhot 2:1')],
        }),
  ),
  catchUpHistoryGapReporterProvider.overrideWithValue(onGap ?? (_) {}),
];
