/// The Dashboard's forecast read path (Story 2.11, DNI-502; AD-35).
///
/// Every number here is a [LearnerState] value from the one engine run of
/// the active learner ([activeLearnerStateProvider], Story 2.3). Nothing is
/// derived: status, projected finish, deadline, daily target and each
/// sub-track's FR-19 shortfall are copied, never recomputed (AD-44), so a
/// recompute (a new event, a catch-up after a lock) reaches the cards by
/// itself and no count is cached in widget state.
///
/// The status, daily target and calendar shortfall go through the lifetime
/// report's own mapping ([OnTrackView.of], Story 5.3, DNI-518), so the
/// Dashboard and the report cannot disagree for one state (DNI-518 AC-11).
///
/// * [parentForecastProvider] is parent-only (NFR-9, UX-DR-48): it builds
///   nothing unless [parentSessionProvider] says the session is a parent's,
///   so a child or tutored session never holds status, projection or
///   shortfall values, not even off screen.
/// * [learnerTodayProvider] is the encouragement read every role may see
///   (UX-DR-67): today's new leaves, the daily target and the streak.
///
/// Plain Riverpod providers (no codegen), matching the C0 provider style.
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/progress.dart';

/// One sub-track whose ground will not all be reached before the deadline
/// (FR-21): the engine's [SubTrackState] values for the warning copy.
@immutable
final class ShortfallWarning {
  /// Creates a warning.
  const ShortfallWarning({
    required this.curriculumId,
    required this.subTrackId,
    required this.name,
    required this.shortfall,
    this.lastShortfallNode,
    this.windowEnd,
  });

  /// The sub-track's curriculum (storage key).
  final String curriculumId;

  /// The sub-track ULID.
  final String subTrackId;

  /// The sub-track's name.
  final String name;

  /// [SubTrackState.shortfall]: the engine's de-duplicated FR-19 count.
  final int shortfall;

  /// [SubTrackState.lastShortfallNode].
  final NodeEntry? lastShortfallNode;

  /// [SubTrackState.windowEnd]; null for an open ongoing window.
  final CivilDate? windowEnd;

  @override
  bool operator ==(Object other) =>
      other is ShortfallWarning &&
      other.curriculumId == curriculumId &&
      other.subTrackId == subTrackId &&
      other.name == name &&
      other.shortfall == shortfall &&
      other.lastShortfallNode == lastShortfallNode &&
      other.windowEnd == windowEnd;

  @override
  int get hashCode => Object.hash(
    curriculumId,
    subTrackId,
    name,
    shortfall,
    lastShortfallNode,
    windowEnd,
  );
}

/// The parent forecast of one evaluated curriculum (FR-18 to FR-21).
@immutable
final class CurriculumForecast {
  /// Creates a forecast.
  const CurriculumForecast({
    required this.curriculumId,
    required this.projection,
    required this.onTrack,
    this.shortfalls = const [],
  });

  /// The curriculum (storage key).
  final String curriculumId;

  /// [CurriculumState.projection], as the engine evaluated it: the
  /// projected finish and the deadline.
  final Projection projection;

  /// The engine's status, daily target and calendar shortfall under the
  /// lifetime report's mapping ([OnTrackView.of]).
  final OnTrackView onTrack;

  /// [CurriculumState.dailyTarget] as [onTrack] shows it: null with no
  /// deadline (FR-20), whatever the engine derived.
  int? get dailyTarget => onTrack.dailyTarget;

  /// One warning per sub-track with a positive shortfall, by name.
  final List<ShortfallWarning> shortfalls;

  /// The curriculum's enum value, or null for an unknown storage key.
  CurriculumId? get curriculum => CurriculumId.fromStorageKey(curriculumId);
}

/// Today's encouragement figures of one evaluated curriculum (UX-DR-67).
@immutable
final class CurriculumToday {
  /// Creates the figures.
  const CurriculumToday({
    required this.curriculumId,
    required this.done,
    this.target,
    this.streak,
  });

  /// The curriculum (storage key).
  final String curriculumId;

  /// [Projection.newlyLearntToday].
  final int done;

  /// [CurriculumState.dailyTarget]; null without one.
  final int? target;

  /// [CurriculumState.streak].
  final CurriculumStreak? streak;

  /// The curriculum's enum value, or null for an unknown storage key.
  CurriculumId? get curriculum => CurriculumId.fromStorageKey(curriculumId);
}

/// The evaluated curricula of [state] (active tracks with a corpus), in
/// the app's curriculum order; unknown keys last, by key.
List<CurriculumState> _evaluated(LearnerState state) {
  int rank(String key) {
    final id = CurriculumId.fromStorageKey(key);
    return id == null ? CurriculumId.values.length : id.index;
  }

  return [
    for (final c in state.curricula.values)
      if (c.evaluated && c.projection != null) c,
  ]..sort((a, b) {
    final byRank = rank(a.curriculumId).compareTo(rank(b.curriculumId));
    return byRank != 0 ? byRank : a.curriculumId.compareTo(b.curriculumId);
  });
}

/// The active learner's state as an [AsyncValue], mapped by [build]: a
/// first load is loading, a refresh of the same learner over a value keeps
/// showing it (no spinner after a tick, UX-DR-102), an error is forwarded,
/// and no learner is an empty list.
///
/// Fail closed on a learner change: while the learner scope re-resolves (a
/// profile switch, a PIN or tutor change) the active state still serves the
/// previous learner, so the value is loading and none of that learner's
/// figures are shown under the next one.
AsyncValue<List<T>> _fromActiveState<T>(
  Ref ref,
  List<T> Function(LearnerState state) build,
) {
  // Watched first so the learner-state subscription stays alive through a
  // scope re-resolve (no dispose and engine re-run on every switch).
  final state = ref.watch(activeLearnerStateProvider);
  if (ref.watch(activeLearnerScopeProvider).isLoading) {
    return AsyncLoading<List<T>>();
  }
  if (state case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<List<T>>(error, stackTrace);
  }
  if (!state.hasValue) return AsyncLoading<List<T>>();
  final learner = state.requireValue;
  if (learner == null) return AsyncData<List<T>>(const []);
  return AsyncData<List<T>>(build(learner));
}

/// The parent forecast cards of the active learner, one per evaluated
/// curriculum.
///
/// Fail closed: only a confirmed parent session reads the learner state.
/// Until the role resolves (or while it re-resolves), and for any session
/// that is not a parent's (a child without the parent PIN, a tutored
/// session, an error), the value is an empty list, so not even the loading
/// placeholder or its "Loading pace status" label reaches a child's first
/// frame (NFR-9, UX-DR-48, UX-DR-97). Loading and error states exist only
/// after parent authorization.
final parentForecastProvider =
    Provider.autoDispose<AsyncValue<List<CurriculumForecast>>>((ref) {
      final access = ref.watch(parentSessionProvider);
      if (access.isLoading || access.hasError || access.value != true) {
        return const AsyncData(<CurriculumForecast>[]);
      }
      return _fromActiveState(
        ref,
        (state) => [
          for (final c in _evaluated(state))
            CurriculumForecast(
              curriculumId: c.curriculumId,
              projection: c.projection!,
              // Non-null: [_evaluated] keeps only projected curricula.
              onTrack: OnTrackView.of(c, c.report)!,
              shortfalls:
                  [
                    for (final s in c.subTracks.values)
                      if (s.shortfall > 0)
                        ShortfallWarning(
                          curriculumId: c.curriculumId,
                          subTrackId: s.subTrackId,
                          name: s.name ?? '',
                          shortfall: s.shortfall,
                          lastShortfallNode: s.lastShortfallNode,
                          windowEnd: s.windowEnd,
                        ),
                  ]..sort((a, b) {
                    final byName = a.name.compareTo(b.name);
                    return byName != 0
                        ? byName
                        : a.subTrackId.compareTo(b.subTrackId);
                  }),
            ),
        ],
      );
    });

/// Today's encouragement figures of the active learner, one per evaluated
/// curriculum, for every role (child, parent, tutor).
final learnerTodayProvider =
    Provider.autoDispose<AsyncValue<List<CurriculumToday>>>(
      (ref) => _fromActiveState(
        ref,
        (state) => [
          for (final c in _evaluated(state))
            CurriculumToday(
              curriculumId: c.curriculumId,
              done: c.projection!.newlyLearntToday,
              target: c.dailyTarget,
              streak: c.streak,
            ),
        ],
      ),
    );

/// Re-reads the forecast inputs after a load error (the `InlineAsyncError`
/// retry, UX-DR-112): [retryLearnerState] (DNI-474), which re-reads the
/// learner scope, the repositories, any failed corpus or calendar input and
/// the engine composition, so a calendar or content failure recovers too.
void retryLearnerForecast(WidgetRef ref) => retryLearnerState(ref);

/// Resolves *View {name} →* for one Dashboard shortfall warning
/// (UX-DR-68): the tap action that opens that sub-track's detail, or null
/// when the detail cannot be opened from here, in which case the card shows
/// no action at all (never a disabled button, never another screen).
typedef SubTrackDetailOpener =
    VoidCallback? Function(BuildContext context, ShortfallWarning warning);

/// The production *View {name} →* action (AC-5): pushes the warning's
/// sub-track detail, Story 2.6's (DNI-497) typed [SubTrackDetailRoute], on
/// the root router, where that route is registered (top level, above the
/// tab shell). Null, so the action is hidden, only when the context has no
/// router. Nothing here reaches a user before the
/// DNI-490 cutover (AD-49 ship hold).
VoidCallback? subTrackDetailAction(
  BuildContext context,
  ShortfallWarning warning,
) {
  final router = StackRouterScope.of(context)?.controller;
  if (router == null) return null;
  final route = SubTrackDetailRoute(subTrackId: warning.subTrackId);
  return () => unawaited(router.root.push<void>(route));
}

/// Where *View {name} →* leads (AC-5): [subTrackDetailAction] in
/// production. Tests override it to observe the tap.
final subTrackDetailOpenerProvider = Provider<SubTrackDetailOpener>(
  (ref) => subTrackDetailAction,
);
