/// Riverpod reads behind the sub-track surfaces.
///
/// - The Manage tracks Sub-tracks group and the school-year form (Story 2.4
///   / DNI-495). Every read goes through the Story 2.1 / C0 ports
///   ([subTrackRepositoryProvider], [governedIntentRepositoryProvider],
///   [learningCommandsProvider], [activeLearnerStateProvider]); presentation
///   adds no Firestore access of its own (AD-23, Story 2.4 DoD).
/// - The Learn-tab / Dashboard sub-track projection (Story 2.9, DNI-500).
///   One projection feeds both surfaces: [homeSubTracksProvider] joins the
///   active learner's complete `sub_tracks` read with the engine's
///   [LearnerState] (AD-35) through [projectHomeSubTracks]. Widgets render
///   it and never recompute a position, a count or a fill. DNI-500 adds no
///   parallel data source (story open assumption).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';

/// Whether the current session may see and use sub-track write entry
/// points (AC-3): a parent acting for the active learner.
///
/// The one shared parent-session rule ([parentSessionProvider]): an adult
/// profile is its own parent; a child profile only while the parent PIN was
/// verified for that same profile this session; a tutored session, no
/// active profile, or any read failure is false (fail closed). The router's
/// parent-session guard reads the same provider, so an override here also
/// drives the guard.
final subTrackParentSessionProvider = parentSessionProvider;

/// The live answer of [subTrackParentSessionProvider], read fresh at a
/// command boundary: every sub-track and governed-goal write asks again
/// just before it submits, because the parent session can end (PIN lock)
/// after the screen was opened (DNI-495 AC-3).
///
/// Holds a subscription until the future resolves, so the auto-dispose
/// provider is not torn down mid-read. Fails closed: a disposed [ref] or
/// any read error is `false`.
Future<bool> readSubTrackParentSession(WidgetRef ref) async {
  ProviderSubscription<Future<bool>>? sub;
  try {
    sub = ref.listenManual(subTrackParentSessionProvider.future, (_, _) {});
    return await sub.read();
  } on Object {
    return false;
  } finally {
    sub?.close();
  }
}

/// The live answer of [subTrackParentSessionProvider], read fresh at a
/// command boundary: every sub-track and governed-goal write asks again
/// just before it submits, because the parent session can end (PIN lock)
/// after the screen was opened (DNI-495 AC-3).
///
/// Holds a subscription until the future resolves, so the auto-dispose
/// provider is not torn down mid-read. Fails closed: a disposed [ref] or
/// any read error is `false`.
Future<bool> readSubTrackParentSession(WidgetRef ref) async {
  ProviderSubscription<Future<bool>>? sub;
  try {
    sub = ref.listenManual(subTrackParentSessionProvider.future, (_, _) {});
    return await sub.read();
  } on Object {
    return false;
  } finally {
    sub?.close();
  }
}

/// The learner's civil "today" (AD-41) for the academic-year picker and the
/// AD-45 checks. Overridden in tests.
final subTrackTodayProvider = Provider.autoDispose<CivilDate>((ref) {
  final now = DateTimeFactory.nowLocal();
  return civilDateOf(now.year, now.month, now.day);
});

/// A complete `sub_tracks` read that holds rows the codec rejected
/// ([CompleteReadReady.rejected]).
///
/// The read is complete but not authoritative: a dropped row would vanish
/// from the Manage tracks hub, from the form's AD-45 sibling checks and from
/// the Learn/Dashboard section. [learnerSubTracksProvider] and
/// [subTracksForScopeProvider] emit this as an error instead (fail closed)
/// until a clean read arrives.
final class SubTrackRowsRejectedException implements Exception {
  /// Creates the exception for the [rejected] rows.
  SubTrackRowsRejectedException(List<RejectedRow> rejected)
    : rejected = List.unmodifiable(rejected);

  /// The rows that failed strict decode, in document-id order.
  final List<RejectedRow> rejected;

  @override
  String toString() =>
      'SubTrackRowsRejectedException(${rejected.length} rejected: '
      '${rejected.map((r) => r.docId).join(', ')})';
}

/// A sub-track read port is not available: no active learner, or no
/// repository for it. The read fails instead of answering "nothing", so no
/// screen mistakes an unknown state for an empty list or a self-paced
/// curriculum (fail closed).
final class SubTrackReadUnavailableException implements Exception {
  /// Creates the exception for the unavailable [port].
  const SubTrackReadUnavailableException(this.port);

  /// What is unavailable (`learner`, `sub_tracks`, `governed_intent`).
  final String port;

  @override
  String toString() => 'SubTrackReadUnavailableException($port)';
}

/// The complete governed-intent read has no main track for the curriculum
/// a sub-track surface was opened for (e.g. a deep link naming an arbitrary
/// curriculum id). Fails closed: no sub-track group and no form, so no
/// sub-track is ever written for a curriculum the learner does not follow.
final class SubTrackMainTrackNotFoundException implements Exception {
  /// Creates the exception for [curriculumId].
  const SubTrackMainTrackNotFoundException(this.curriculumId);

  /// The curriculum (storage key) with no main track.
  final String curriculumId;

  @override
  String toString() => 'SubTrackMainTrackNotFoundException($curriculumId)';
}

/// Every sub-track of the active learner (all curricula, live and ended),
/// from the complete Story 2.1 read. Emits nothing while the read is
/// loading. No active learner or no repository is an error
/// ([SubTrackReadUnavailableException]), never an empty list. A complete
/// read with undecodable rows is an error ([SubTrackRowsRejectedException]),
/// so the hub shows its error state and the form never opens on partial
/// data; a later clean read recovers.
final learnerSubTracksProvider = StreamProvider.autoDispose<List<SubTrack>>((
  ref,
) async* {
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  if (scope == null) {
    throw const SubTrackReadUnavailableException('learner');
  }
  final repository = await ref.watch(subTrackRepositoryProvider.future);
  if (repository == null) {
    throw const SubTrackReadUnavailableException('sub_tracks');
  }
  yield* repository
      .watchAll(scope)
      .where((read) => read is CompleteReadReady<SubTrack>)
      .map((read) {
        final ready = read as CompleteReadReady<SubTrack>;
        if (!ready.isClean) {
          throw SubTrackRowsRejectedException(ready.rejected);
        }
        return ready.items;
      });
}, retry: (retryCount, error) => null);

/// What the sub-track UI needs from one curriculum's governed intent.
final class SubTrackCurriculumIntent {
  /// Creates the value.
  const SubTrackCurriculumIntent({this.calendarProgramId, this.deadline});

  /// The live `profile_programs/{curriculumId}.program_id`, or null for a
  /// self-paced main track.
  final String? calendarProgramId;

  /// The live deadline goal's `target_date` (AD-43), or null.
  final CivilDate? deadline;

  /// Whether the main track follows a calendar program: no sub-tracks
  /// (AD-45, AC-2).
  bool get followsCalendarProgram => calendarProgramId != null;

  @override
  bool operator ==(Object other) =>
      other is SubTrackCurriculumIntent &&
      other.calendarProgramId == calendarProgramId &&
      other.deadline == deadline;

  @override
  int get hashCode => Object.hash(calendarProgramId, deadline);
}

/// The calendar-program and deadline state of curriculum `curriculumId`
/// (its storage key), from the complete governed-intent read. No active
/// learner or no repository is an error
/// ([SubTrackReadUnavailableException]): an unknown intent is never taken
/// for a self-paced curriculum (that would show *Add sub-track* on a
/// calendar program). A complete read with no main track for
/// `curriculumId` is an error too ([SubTrackMainTrackNotFoundException]),
/// never a self-paced curriculum.
final subTrackCurriculumIntentProvider = StreamProvider.autoDispose
    .family<SubTrackCurriculumIntent, String>((ref, curriculumId) async* {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) {
        throw const SubTrackReadUnavailableException('learner');
      }
      final repository = await ref.watch(
        governedIntentRepositoryProvider.future,
      );
      if (repository == null) {
        throw const SubTrackReadUnavailableException('governed_intent');
      }
      // An error event per emission, not a throw out of the loop: the read
      // keeps listening, so a later intent with the main track recovers.
      yield* repository.watch(scope).map((intent) {
        final mainTrack = intent.mainTracks[curriculumId];
        if (mainTrack == null) {
          throw SubTrackMainTrackNotFoundException(curriculumId);
        }
        final program = mainTrack.program;
        final deadline = intent.goals[curriculumId]?.deadline;
        return SubTrackCurriculumIntent(
          calendarProgramId: program == null || program.endedAt != null
              ? null
              : program.programId,
          deadline: deadline == null || deadline.endedAt != null
              ? null
              : deadline.targetDate,
        );
      });
    }, retry: (retryCount, error) => null);

/// Sub-track changes a queued batch the server later refused for good
/// (Story 2.1 "not saved — retry" entries), live. Empty while no learner is
/// active or the commands are not available.
final subTrackPendingFailuresProvider =
    StreamProvider.autoDispose<List<PendingFailure>>((ref) async* {
      final commands = await ref.watch(learningCommandsProvider.future);
      if (commands == null) {
        yield const [];
        return;
      }
      await for (final failures in commands.watchPendingFailures()) {
        yield [
          // Sub-track batches carry a change-log entry and no events.
          for (final f in failures)
            if (f.eventIds.isEmpty && f.changeIds.isNotEmpty) f,
        ];
      }
    }, retry: (retryCount, error) => null);

/// The plural leaf-unit label of curriculum `curriculumId` (its storage
/// key), e.g. "Mishnayos" — sub-track rates are in leaf units
/// (`prd-deviations` #12). Follows the Hebrew-terms toggle and nusach.
String subTrackLeafUnitLabel(WidgetRef ref, String curriculumId) {
  final id = CurriculumId.fromStorageKey(curriculumId);
  if (id == null) return curriculumId;
  return CurriculumLabels.leaf(id).inLanguage(
    useHebrew: domainTermLabels(ref).isHebrew,
    plural: true,
    variant: ref.watch(currentTransliterationVariantProvider),
  );
}

/// Opens the existing goal setup of [curriculum] from a sub-track form's
/// no-deadline link (AC-6) and saves it through the governed contract;
/// resolves to what happened, for the form to report.
typedef SubTrackGoalSetupLauncher =
    Future<SubTrackGoalSetupOutcome> Function(
      BuildContext context,
      WidgetRef ref,
      CurriculumId curriculum,
    );

/// The goal-setup flow the no-deadline link opens:
/// [openSubTrackGoalSetup]. A seam so form tests can observe the link
/// without the whole goal screen.
final subTrackGoalSetupLauncherProvider = Provider<SubTrackGoalSetupLauncher>(
  (ref) => openSubTrackGoalSetup,
);

/// Every sub-track of [LearnerScope] (live and tombstoned) once the complete
/// read is in; loading until then, never partial (AD-54). Empty while no
/// account is ready (the repository provider is null).
///
/// A complete read with rejected rows is emitted as a
/// [SubTrackRowsRejectedException] error, never as the valid rows alone
/// (the [CompleteReadReady] contract: rejected rows are surfaced, not
/// dropped). The stream keeps listening, so a later clean read recovers.
final subTracksForScopeProvider = StreamProvider.autoDispose
    .family<List<SubTrack>, LearnerScope>((ref, scope) async* {
      final repository = await ref.watch(subTrackRepositoryProvider.future);
      if (repository == null) {
        yield const <SubTrack>[];
        return;
      }
      await for (final read in repository.watchAll(scope)) {
        switch (read) {
          case CompleteReadLoading<SubTrack>():
            break;
          case CompleteReadReady<SubTrack>(:final items, isClean: true):
            yield items;
          case CompleteReadReady<SubTrack>(:final rejected):
            yield* Stream<List<SubTrack>>.error(
              SubTrackRowsRejectedException(rejected),
              StackTrace.current,
            );
        }
      }
    }, retry: (retryCount, error) => null);

/// The active learner's `onHome` sub-tracks in hub order (AC-1, AC-8).
///
/// * `AsyncData([])` while no learner is active, or when the learner has no
///   sub-track at all (the engine is not consulted, so the section is simply
///   absent).
/// * Loading while either input is still loading; the caller keeps that
///   local to its own section (AC-6).
/// * An error from either input is forwarded, for the section's
///   `InlineAsyncError` + retry ([retryHomeSubTracks]). That includes a
///   sub-track read with rejected rows ([SubTrackRowsRejectedException]):
///   the projection is never shown as clean while a row is missing.
final homeSubTracksProvider =
    Provider.autoDispose<AsyncValue<List<SubTrackHomeItem>>>((ref) {
      final scopeAsync = ref.watch(activeLearnerScopeProvider);
      if (scopeAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!scopeAsync.hasValue) return const AsyncLoading();
      final scope = scopeAsync.requireValue;
      if (scope == null) return const AsyncData([]);

      final tracksAsync = ref.watch(subTracksForScopeProvider(scope));
      if (tracksAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!tracksAsync.hasValue) return const AsyncLoading();
      final tracks = tracksAsync.requireValue;
      if (tracks.isEmpty) return const AsyncData([]);

      final stateAsync = ref.watch(learnerStateProvider(scope));
      if (stateAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!stateAsync.hasValue) return const AsyncLoading();
      return AsyncData(
        projectHomeSubTracks(
          subTracks: tracks,
          learnerState: stateAsync.requireValue,
        ),
      );
    });

/// Retries the failed inputs of [homeSubTracksProvider] (the section's
/// retry action, AC-6). The shared scope is re-resolved only when it is the
/// input that failed, so a sub-track retry never churns the rest of the app.
void retryHomeSubTracks(WidgetRef ref) {
  if (ref.read(activeLearnerScopeProvider).hasError) {
    ref.invalidate(activeLearnerScopeProvider);
  }
  ref
    ..invalidate(subTracksForScopeProvider)
    ..invalidate(learnerStateProvider);
}
