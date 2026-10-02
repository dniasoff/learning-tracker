/// Riverpod access to the Learn-tab / Dashboard sub-track projection
/// (Story 2.9, DNI-500).
///
/// One projection feeds both surfaces: [homeSubTracksProvider] joins the
/// active learner's complete `sub_tracks` read with the engine's
/// [LearnerState] (AD-35) through [projectHomeSubTracks]. Widgets render it
/// and never recompute a position, a count or a fill.
///
/// Production wiring: [learnerStateProvider] is the C0 (DNI-524) seam that
/// DNI-474 fills. Until it does, a learner with sub-tracks gets the
/// section's `InlineAsyncError` (AC-6); the main tasks are unaffected.
/// DNI-500 adds no parallel data source (story open assumption). The stub
/// cannot ship: DNI-490 removes every `c0Stub` call before the cutover
/// release (`tool/retired_symbols/R15.json`). The no-override integration
/// test follows in bead learning-tracker-fyh.135.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

/// A complete `sub_tracks` read that holds rows the codec rejected
/// ([CompleteReadReady.rejected]).
///
/// The read is complete but not authoritative: projecting only the valid
/// rows would show the Learn/Dashboard section as clean while a sub-track
/// the app cannot interpret silently vanished. [subTracksForScopeProvider]
/// emits this as an error instead, so the section shows its
/// `InlineAsyncError` + retry (AC-6) until a clean read arrives.
final class SubTrackRowsRejectedException implements Exception {
  /// Creates the exception for the [rejected] rows.
  SubTrackRowsRejectedException(List<RejectedRow> rejected)
  /// The rows that failed strict decode, in document-id order.
  @override
  String toString() =>
      'SubTrackRowsRejectedException(${rejected.length} rejected: '
}
/// Every sub-track of [LearnerScope] (live and tombstoned) once the complete
/// read is in; loading until then, never partial (AD-54). Empty while no
/// account is ready (the repository provider is null).
/// A complete read with rejected rows is emitted as a
/// [SubTrackRowsRejectedException] error, never as the valid rows alone
/// (the [CompleteReadReady] contract: rejected rows are surfaced, not
/// dropped). The stream keeps listening, so a later clean read recovers.
final subTracksForScopeProvider = StreamProvider.autoDispose
    .family<List<SubTrack>, LearnerScope>((ref, scope) async* {
      if (repository == null) {
      }
      await for (final read in repository.watchAll(scope)) {
        switch (read) {
          case CompleteReadLoading<SubTrack>():
          case CompleteReadReady<SubTrack>(:final items, isClean: true):
          case CompleteReadReady<SubTrack>(:final rejected):
            yield* Stream<List<SubTrack>>.error(
              SubTrackRowsRejectedException(rejected),
              StackTrace.current,
        }
/// The active learner's `onHome` sub-tracks in hub order (AC-1, AC-8).
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
      if (scopeAsync case AsyncError(:final error, :final stackTrace)) {
      if (tracksAsync case AsyncError(:final error, :final stackTrace)) {
      if (stateAsync case AsyncError(:final error, :final stackTrace)) {
      return AsyncData(
        projectHomeSubTracks(
          subTracks: tracks,
          learnerState: stateAsync.requireValue,
        ),
/// Retries the failed inputs of [homeSubTracksProvider] (the section's
/// retry action, AC-6). The shared scope is re-resolved only when it is the
/// input that failed, so a sub-track retry never churns the rest of the app.
void retryHomeSubTracks(WidgetRef ref) {
  if (ref.read(activeLearnerScopeProvider).hasError) {
  }
  ref
    ..invalidate(subTracksForScopeProvider)
/// Riverpod reads behind the Manage tracks Sub-tracks group and the
/// school-year form (Story 2.4 / DNI-495).
/// Every read goes through the Story 2.1 / C0 ports
/// ([subTrackRepositoryProvider], [governedIntentRepositoryProvider],
/// [learningCommandsProvider], [activeLearnerStateProvider]); presentation
/// adds no Firestore access of its own (AD-23, Story 2.4 DoD).
import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
/// Whether the current session may see and use sub-track write entry
/// points (AC-3): a parent acting for the active learner.
/// - a child profile: true only while the parent PIN was verified for that
/// - no active profile, or any read failure: false (fail closed).
final subTrackParentSessionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
  } on Object {
/// The learner's civil "today" (AD-41) for the academic-year picker and the
/// AD-45 checks. Overridden in tests.
final subTrackTodayProvider = Provider.autoDispose<CivilDate>((ref) {
/// The sub-track UI could not resolve one of its required read ports.
final class SubTrackReadUnavailableException implements Exception {
  /// Creates the exception for [port].
  const SubTrackReadUnavailableException(this.port);

  /// The unavailable port (`learner`, `sub_tracks`, or `governed_intent`).
  final String port;

  @override
  String toString() => 'SubTrackReadUnavailableException($port)';
}

/// Every sub-track of the active learner (all curricula, live and ended),
/// from the complete Story 2.1 read. Emits nothing while the read is
/// loading; an empty list when no learner is active.
final learnerSubTracksProvider = StreamProvider.autoDispose<List<SubTrack>>((
) async* {
  if (scope == null) {
  if (repository == null) {
  await for (final read in repository.watchAll(scope)) {
/// What the sub-track UI needs from one curriculum's governed intent.
final class SubTrackCurriculumIntent {
  /// Creates the value.
  /// The live `profile_programs/{curriculumId}.program_id`, or null for a
  /// self-paced main track.
  /// The live deadline goal's `target_date` (AD-43), or null.
  /// Whether the main track follows a calendar program: no sub-tracks
  /// (AD-45, AC-2).
  bool operator ==(Object other) =>
      other is SubTrackCurriculumIntent &&
      other.calendarProgramId == calendarProgramId &&
/// The calendar-program and deadline state of curriculum `curriculumId`
/// (its storage key), from the complete governed-intent read.
final subTrackCurriculumIntentProvider = StreamProvider.autoDispose
    .family<SubTrackCurriculumIntent, String>((ref, curriculumId) async* {
      if (scope == null) {
      final repository = await ref.watch(
        governedIntentRepositoryProvider.future,
      await for (final intent in repository.watch(scope)) {
        yield SubTrackCurriculumIntent(
          calendarProgramId: program == null || program.endedAt != null
              ? null
              : program.programId,
          deadline: deadline == null || deadline.endedAt != null
              : deadline.targetDate,
/// Sub-track changes a queued batch the server later refused for good
/// (Story 2.1 "not saved — retry" entries), live. Empty while no learner is
/// active or the commands are not available.
final subTrackPendingFailuresProvider =
    StreamProvider.autoDispose<List<PendingFailure>>((ref) async* {
      if (commands == null) {
      await for (final failures in commands.watchPendingFailures()) {
        yield [
          // Sub-track batches carry a change-log entry and no events.
          for (final f in failures)
            if (f.eventIds.isEmpty && f.changeIds.isNotEmpty) f,
/// The plural leaf-unit label of curriculum `curriculumId` (its storage
/// key), e.g. "Mishnayos" — sub-track rates are in leaf units
/// (`prd-deviations` #12). Follows the Hebrew-terms toggle and nusach.
String subTrackLeafUnitLabel(WidgetRef ref, String curriculumId) {
  return CurriculumLabels.leaf(id).inLanguage(
    useHebrew: domainTermLabels(ref).isHebrew,
    plural: true,
    variant: ref.watch(currentTransliterationVariantProvider),
/// Opens the existing goal setup of [curriculum] from a sub-track form's
/// no-deadline link (AC-6); resolves to whether a goal was saved.
typedef SubTrackGoalSetupLauncher =
    Future<bool> Function(
      BuildContext context,
      WidgetRef ref,
      CurriculumId curriculum,
/// The goal-setup flow the no-deadline link opens: the shared
/// [openCurriculumGoalSetup]. A seam so form tests can observe the link
/// without the whole goal screen.
final subTrackGoalSetupLauncherProvider = Provider<SubTrackGoalSetupLauncher>(
  (ref) => openCurriculumGoalSetup,

/// A complete `sub_tracks` read that holds rows the codec rejected
/// ([CompleteReadReady.rejected]).
///
/// The read is complete but not authoritative: projecting only the valid
/// rows would show the Learn/Dashboard section as clean while a sub-track
/// the app cannot interpret silently vanished. [subTracksForScopeProvider]
/// emits this as an error instead, so the section shows its
/// `InlineAsyncError` + retry (AC-6) until a clean read arrives.
final class SubTrackRowsRejectedException implements Exception {
  /// Creates the exception for the [rejected] rows.
  SubTrackRowsRejectedException(List<RejectedRow> rejected)
    : rejected = List.unmodifiable(rejected);

  /// The rows that failed strict decode, in document-id order.
  final List<RejectedRow> rejected;

  /// Rejected document ids, for surfaces that report concise diagnostics.
  List<String> get docIds => [for (final row in rejected) row.docId];

  @override
  String toString() =>
      'SubTrackRowsRejectedException(${rejected.length} rejected: '
      '${rejected.map((r) => r.docId).join(', ')})';
}

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

/// Whether the current session may see and use sub-track write entry
/// points (AC-3): a parent acting for the active learner.
///
/// - an adult profile is its own parent: true;
/// - a child profile: true only while the parent PIN was verified for that
///   same profile this session (`parentPinAuthenticatedProfileIdProvider`);
/// - a tutored session: false (tutor sub-track writes arrive with Epic 4);
/// - no active profile, or any read failure: false (fail closed).
final subTrackParentSessionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return false;
  final pinProfileId = ref.watch(parentPinAuthenticatedProfileIdProvider);
  try {
    final profile = await ref.watch(activeProfileProvider.future);
    if (profile == null) return false;
    if (profile.mode != ProfileMode.child) return true;
    return pinProfileId != null && pinProfileId == profile.profileId;
  } on Object {
    return false;
  }
}, retry: (retryCount, error) => null);

/// The learner's civil "today" (AD-41) for the academic-year picker and the
/// AD-45 checks. Overridden in tests.
final subTrackTodayProvider = Provider.autoDispose<CivilDate>((ref) {
  final now = DateTimeFactory.nowLocal();
  return civilDateOf(now.year, now.month, now.day);
});

/// Every sub-track of the active learner (all curricula, live and ended),
/// from the complete Story 2.1 read. Emits nothing while the read is
/// loading; an empty list when no learner is active.
final learnerSubTracksProvider = StreamProvider.autoDispose<List<SubTrack>>((
  ref,
) async* {
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  if (scope == null) {
    yield const [];
    return;
  }
  final repository = await ref.watch(subTrackRepositoryProvider.future);
  if (repository == null) {
    yield const [];
    return;
  }
  await for (final read in repository.watchAll(scope)) {
    switch (read) {
      case CompleteReadReady<SubTrack>(:final items, isClean: true):
        yield items;
      case CompleteReadReady<SubTrack>(:final rejected):
        throw SubTrackRowsRejectedException(rejected);
      case CompleteReadLoading<SubTrack>():
        break;
    }
  }
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
/// (its storage key), from the complete governed-intent read.
final subTrackCurriculumIntentProvider = StreamProvider.autoDispose
    .family<SubTrackCurriculumIntent, String>((ref, curriculumId) async* {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) {
        yield const SubTrackCurriculumIntent();
        return;
      }
      final repository = await ref.watch(
        governedIntentRepositoryProvider.future,
      );
      if (repository == null) {
        yield const SubTrackCurriculumIntent();
        return;
      }
      await for (final intent in repository.watch(scope)) {
        final program = intent.mainTracks[curriculumId]?.program;
        final deadline = intent.goals[curriculumId]?.deadline;
        yield SubTrackCurriculumIntent(
          calendarProgramId: program == null || program.endedAt != null
              ? null
              : program.programId,
          deadline: deadline == null || deadline.endedAt != null
              ? null
              : deadline.targetDate,
        );
      }
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

/// Whether the current session may see and use sub-track write entry
/// points (AC-3): a parent acting for the active learner.
///
/// - an adult profile is its own parent: true;
/// - a child profile: true only while the parent PIN was verified for that
///   same profile this session (`parentPinAuthenticatedProfileIdProvider`);
/// - a tutored session: false (tutor sub-track writes arrive with Epic 4);
/// - no active profile, or any read failure: false (fail closed).
final subTrackParentSessionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return false;
  final pinProfileId = ref.watch(parentPinAuthenticatedProfileIdProvider);
  try {
    final profile = await ref.watch(activeProfileProvider.future);
    if (profile == null) return false;
    if (profile.mode != ProfileMode.child) return true;
    return pinProfileId != null && pinProfileId == profile.profileId;
  } on Object {
    return false;
  }
}, retry: (retryCount, error) => null);

/// The learner's civil "today" (AD-41) for the academic-year picker and the
/// AD-45 checks. Overridden in tests.
final subTrackTodayProvider = Provider.autoDispose<CivilDate>((ref) {
  final now = DateTimeFactory.nowLocal();
  return civilDateOf(now.year, now.month, now.day);
});

/// The learner's complete sub-track read holds rows that failed strict
/// decode (`CompleteReadReady.rejected`). The list is not trustworthy: a
/// dropped row would vanish from the hub and from the form's AD-45 sibling
/// checks, so the read surfaces as an error instead (fail closed).
final class SubTrackRowsRejectedException implements Exception {
  /// Creates the exception for the rejected [docIds].
  const SubTrackRowsRejectedException(this.docIds);

  /// The ids of the rows that failed decode.
  final List<String> docIds;

  @override
  String toString() =>
      'SubTrackRowsRejectedException(${docIds.length} undecodable rows)';
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
          throw SubTrackRowsRejectedException([
            for (final r in ready.rejected) r.docId,
          ]);
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
/// calendar program).
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
      await for (final intent in repository.watch(scope)) {
        final program = intent.mainTracks[curriculumId]?.program;
        final deadline = intent.goals[curriculumId]?.deadline;
        yield SubTrackCurriculumIntent(
          calendarProgramId: program == null || program.endedAt != null
              ? null
              : program.programId,
          deadline: deadline == null || deadline.endedAt != null
              ? null
              : deadline.targetDate,
        );
      }
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
