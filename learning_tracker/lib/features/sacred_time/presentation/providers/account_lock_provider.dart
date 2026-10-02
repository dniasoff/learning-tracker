/// The learners whose lock drives this device's lock surfaces, and their
/// settings histories (DNI-481 AC-1, AD-36 "Multi-learner devices").
///
/// * Every learner profile of the signed-in account drives the overlay:
///   its window is the union of their `lockWindows`.
/// * A learner viewed through a tutor grant does NOT drive the account
///   overlay; only while a tutored session shows that talmid's screens are
///   they covered by the talmid's lock.
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
/// signed-in account (owner = the account's persisted path uid), plus the
/// talmid of an active tutored session. `AsyncData([])` while signed out;
/// loading / error while the account's profiles load or fail.
final lockDrivingScopesProvider = Provider<AsyncValue<List<LearnerScope>>>((
  ref,
) {
  final tutored = ref.watch(activeTutoredProfileSelectionProvider);
  final talmid = tutored == null
      ? null
      : _scopeOrNull(tutored.ownerUid, tutored.profileId);

  final uid = ref.watch(ownAccountPathUidProvider);
  if (uid case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!uid.hasValue) return const AsyncLoading();
  final ownerUid = uid.requireValue;
  if (ownerUid == null) {
    return AsyncData([?talmid]);
  }

  final profiles = ref.watch(profileListStreamProvider);
  if (profiles case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!profiles.hasValue) return const AsyncLoading();
  return AsyncData([
    for (final profile in profiles.requireValue)
      ?_scopeOrNull(ownerUid, profile.profileId),
    if (talmid != null) talmid,
  ]);
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
