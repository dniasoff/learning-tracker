/// Form-facing selectors for the ongoing sub-track form and its hub entry
/// (Story 2.5 / DNI-496).
///
/// Everything here reads through the Story 2.1 ports re-exported by
/// `ongoing_sub_track_sources.dart`; no Firestore access is added. The
/// derived activity state (`onHome`, `holdsGround`, capacity, the daily
/// target) stays with the engine (Stories 2.2/2.3).
///
/// DNI-495 seam: Story 2.4 (Manage tracks hub) was to provide the
/// sub-track selectors and the parent-session gate. It is not on
/// `integ/sub-tracks`, so this story owns the minimal versions below and a
/// follow-up bead folds them into Story 2.4's providers when it lands.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ongoing_sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// The sub-track read held rows the codec rejected. The limit count could
/// miss them, so the hub fails closed instead of showing a partial list.
final class SubTrackRowsUnreadableException implements Exception {
  /// Creates the exception for [count] rejected rows.
  const SubTrackRowsUnreadableException(this.count);

  /// How many rows were rejected.
  final int count;

  @override
  String toString() =>
      'SubTrackRowsUnreadableException: $count sub-track row(s) unreadable';
}

/// What the hub entry and the ongoing form need for one curriculum.
final class OngoingSubTrackContext {
  /// Creates the context.
  OngoingSubTrackContext({
    required this.curriculumId,
    required this.today,
    required List<SubTrack> subTracks,
    required this.calendarProgram,
  }) : subTracks = List.unmodifiable(subTracks);

  /// The curriculum's storage key.
  final String curriculumId;

  /// The learner's civil today, in the profile's `time_zone` (AD-41).
  final CivilDate today;

  /// Every sub-track of [curriculumId], live and ended.
  final List<SubTrack> subTracks;

  /// Whether the main track follows a calendar program (no sub-tracks,
  /// AD-45, prd-deviations #12).
  final bool calendarProgram;

  /// The non-ended sub-tracks, for the hub rows (UX-DR-82: ended ones are
  /// not listed among the active rows).
  List<SubTrack> get liveSubTracks => [
    for (final s in subTracks)
      if (!s.isEnded) s,
  ];

  /// Ongoing sub-tracks counting toward the AD-45 cap, optionally leaving
  /// out the one being edited ([excludingId]).
  int ongoingInUse({String? excludingId}) => ongoingSubTracksInUse(
    subTracks,
    curriculumId: curriculumId,
    today: today,
    excludingId: excludingId,
  );
}

/// The learner's governed intent, live; null while no learner is active or
/// its repository is not ready.
final ongoingSubTrackIntentProvider =
    StreamProvider.autoDispose<LearnerIntent?>((ref) async* {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      final repo = await ref.watch(governedIntentRepositoryProvider.future);
      if (scope == null || repo == null) {
        yield null;
        return;
      }
      yield* repo.watch(scope);
    }, retry: (retryCount, error) => null);

/// Every sub-track of curriculum `curriculumId` (live and ended), as a
/// complete read; null while no learner is active.
final curriculumSubTracksProvider = StreamProvider.autoDispose
    .family<List<SubTrack>?, String>((ref, curriculumId) async* {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      final repo = await ref.watch(subTrackRepositoryProvider.future);
      if (scope == null || repo == null) {
        yield null;
        return;
      }
      await for (final read in repo.watchByCurriculum(scope, curriculumId)) {
        switch (read) {
          case CompleteReadLoading<SubTrack>():
            continue; // loading until complete, never partial
          case CompleteReadReady<SubTrack>(:final items, :final rejected):
            if (rejected.isNotEmpty) {
              throw SubTrackRowsUnreadableException(rejected.length);
            }
            yield items;
        }
      }
    }, retry: (retryCount, error) => null);

/// The [OngoingSubTrackContext] of curriculum `curriculumId`; null while no
/// learner is active. Recomputes when the intent or the sub-tracks change.
final ongoingSubTrackContextProvider = FutureProvider.autoDispose
    .family<OngoingSubTrackContext?, String>((ref, curriculumId) async {
      final intent = await ref.watch(ongoingSubTrackIntentProvider.future);
      final subTracks = await ref.watch(
        curriculumSubTracksProvider(curriculumId).future,
      );
      if (intent == null || subTracks == null) return null;
      final nowUtc = ref.watch(localDayClockProvider).nowUtc();
      final today = formatCivilDay(
        LearnerZone.of(intent.settings.timeZone).dayOf(nowUtc),
      );
      // The live program only, exactly as `SubTrackCommands` reads it.
      final program = intent.mainTracks[curriculumId]?.program;
      return OngoingSubTrackContext(
        curriculumId: curriculumId,
        today: today,
        subTracks: subTracks,
        calendarProgram:
            program != null &&
            program.endedAt == null &&
            program.programId != null,
      );
    }, retry: (retryCount, error) => null);

/// Whether a sub-track write surface may be shown: an adult profile (the
/// learner is the parent), or a child profile whose parent PIN was
/// verified this session. A tutored session is refused (tutor sub-track
/// writes are Epic 4). Fails closed while the profile resolves.
final ongoingSubTrackParentSessionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return false;
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) return false;
  if (!profile.mode.isChild) return true;
  return ref.watch(parentPinAuthenticatedProfileIdProvider) ==
      profile.profileId;
}, retry: (retryCount, error) => null);
