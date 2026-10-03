/// The learners whose lock drives this device's lock surfaces, and their
/// settings histories (DNI-481 AC-1, AD-36 "Multi-learner devices").
///
/// * Every learner profile of the signed-in account drives the app-wide
///   overlay, notification suppression and reminders: its window is the
///   union of their `lockWindows`.
/// * A learner viewed through a tutor grant NEVER drives that account
///   lock — not even during a tutored session. While a tutored session
///   shows a locked talmid, only the talmid's screens are covered
///   ([tutoredLearnerLockHistoryProvider], `currentTutoredSacredWindow`),
///   and the tutor's own way out of the session stays reachable.
/// * Signed out (no account, or its path uid unbound): no learner, so no
///   lock — sign-in and onboarding stay reachable (DNI-368).
/// * Fail closed: while the account's profiles or a learner's settings are
///   loading or unreadable, that learner is judged with
///   [failClosedSettingsHistory] — never treated as unlocked (NFR-6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/sacred_lock.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// The profile id a fail-closed stand-in history carries when the
/// account's learner list itself cannot be read.
const String unknownAccountLearner = 'account';

/// The learners whose lock drives the device: every learner profile of the
/// signed-in account (owner = the account's persisted path uid). A tutored
/// talmid is never one of them. `AsyncData([])` while signed out; loading /
/// error while the account's profiles load or fail.
final lockDrivingScopesProvider = Provider<AsyncValue<List<LearnerScope>>>((
  ref,
) {
  final uid = ref.watch(ownAccountPathUidProvider);
  if (uid case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!uid.hasValue) return const AsyncLoading();
  final ownerUid = uid.requireValue;
  if (ownerUid == null) return const AsyncData([]);

  final profiles = ref.watch(profileListStreamProvider);
  if (profiles case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!profiles.hasValue) return const AsyncLoading();
  return AsyncData([
    for (final profile in profiles.requireValue)
      ?_scopeOrNull(ownerUid, profile.profileId),
  ]);
});

/// The settings history of the talmid an active tutored session shows, or
/// null outside a tutored session (DNI-481 AC-1 tutor rule, AD-36). Drives
/// only the cover over that talmid's screens, never the account lock.
/// Fail closed: while the talmid's settings load or cannot be read (or
/// the selection names no addressable learner), the talmid is judged with
/// [failClosedSettingsHistory].
final tutoredLearnerLockHistoryProvider = Provider<LearnerSettingsHistory?>((
  ref,
) {
  final tutored = ref.watch(activeTutoredProfileSelectionProvider);
  if (tutored == null) return null;
  final scope = _scopeOrNull(tutored.ownerUid, tutored.profileId);
  if (scope == null) return failClosedSettingsHistory(tutored.profileId);
  return _historyOrFailClosed(
    ref.watch(learnerLockSettingsProvider(scope)),
    scope.profileId,
  );
});

/// A scope, or null for an id pair `LearnerScope` refuses (never a
/// learner the lock could address).
LearnerScope? _scopeOrNull(String ownerUid, String profileId) {
  try {
    return LearnerScope(ownerUid: ownerUid, profileId: profileId);
  } on ArgumentError {
    return null;
  }
}

/// The settings history of every learner in [lockDrivingScopesProvider],
/// each from `learnerLockSettingsProvider` — the ONE settings source of
/// every lock reader (AD-37). A learner whose settings are loading or
/// unreadable, and the whole account while its learner list is, is judged
/// with [failClosedSettingsHistory] (fail closed).
final accountLockHistoriesProvider = Provider<List<LearnerSettingsHistory>>((
  ref,
) {
  final scopes = ref.watch(lockDrivingScopesProvider);
  if (scopes.hasError || !scopes.hasValue) {
    return [failClosedSettingsHistory(unknownAccountLearner)];
  }
  return [
    for (final scope in scopes.requireValue)
      _historyOrFailClosed(
        ref.watch(learnerLockSettingsProvider(scope)),
        scope.profileId,
      ),
  ];
});

LearnerSettingsHistory _historyOrFailClosed(
  AsyncValue<LearnerSettingsHistory> history,
  String profileId,
) {
  if (history.hasError || !history.hasValue) {
    return failClosedSettingsHistory(profileId);
  }
  return history.requireValue;
}

/// The device lock predicate for a UTC instant: [isLockedAt] over
/// [accountLockHistoriesProvider] — the SAME union the lock overlay shows
/// (AD-36), so notification suppression and reminders never disagree with
/// the overlay (DNI-481 AC-5). Rebuilt whenever a learner's settings
/// change, so future scheduling follows a settings change while a past
/// instant keeps the settings in force then.
final deviceLockPredicateProvider = Provider<bool Function(DateTime utc)>((
  ref,
) {
  final histories = ref.watch(accountLockHistoriesProvider);
  return (utc) => isLockedAt(histories, utc);
});
