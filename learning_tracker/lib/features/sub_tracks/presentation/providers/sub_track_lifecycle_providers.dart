/// The sub-track lifecycle's read (Story 2.8 / DNI-499, T4): the learner's
/// civil today (AD-41) that splits the Manage tracks hub into active and
/// ended sub-tracks and bounds *Add next year*.
///
/// The sub-tracks themselves come from Story 2.4's complete read
/// (`learnerSubTracksProvider`, DNI-495) and the detail's engine state
/// (DNI-497). Every lifecycle write goes through `LearningCommands`
/// (`createSubTrack` / `endSubTrack` / `deleteSubTrack`); a passed window
/// is ended by derivation only, never by a write (AD-33, AC-6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';

/// The learner's civil today (AD-41): the current instant in the
/// `time_zone` in force per the learner's settings history, or the UTC date
/// while that history has not loaded (the AD-41 fallback; never the device
/// offset). Recomputed whenever a reader rebuilds, so a window that passes
/// at the learner's midnight moves its sub-track to Ended with no write.
final subTrackLifecycleTodayProvider = Provider.autoDispose<CivilDate>((ref) {
  final nowUtc = ref.watch(localDayClockProvider).nowUtc().toUtc();
  final scope = ref.watch(activeLearnerScopeProvider).value;
  final history = scope == null
      ? null
      : ref.watch(learnerLockSettingsProvider(scope)).value;
  return history == null
      ? formatCivilDay(DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day))
      : civilDate(nowUtc, history);
});
