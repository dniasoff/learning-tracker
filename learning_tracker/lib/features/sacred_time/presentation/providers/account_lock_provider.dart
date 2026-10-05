/// The learners whose lock drives this device's lock surfaces, and their
/// settings histories (DNI-481 AC-1, AD-36 "Multi-learner devices").
///
/// The lock follows the PERSON USING THE DEVICE (product ruling
/// 2026-10-05):
/// * Every learner profile of the signed-in account drives the app-wide
///   overlay, notification suppression and reminders: its window is the
///   union of their `lockWindows`. In a tutored session that is the
///   TUTOR's own account, never the talmid's — a talmid's lock never
///   covers or blocks the tutor.
/// * Signed out (no account, or its path uid unbound), or an account with
///   no learner profile (a tutor-only account): no lock.
/// * Not locked while unknown: a learner whose settings are loading, not
///   ready or unreadable — and the whole account while its learner list
///   is — contributes no lock, and the lock is judged again as soon as the
///   settings arrive (the providers rebuild). No location, no lock
///   (`lockWindows`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/sacred_lock.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

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

/// A scope, or null for an id pair `LearnerScope` refuses (never a
/// learner the lock could address).
LearnerScope? _scopeOrNull(String ownerUid, String profileId) {
  try {
    return LearnerScope(ownerUid: ownerUid, profileId: profileId);
  } on ArgumentError {
    return null;
  }
}

/// The settings history of every learner in [lockDrivingScopesProvider]
/// whose settings have been read, each from `learnerLockSettingsProvider`
/// — the ONE settings source of every lock reader (AD-37). A learner whose
/// settings are loading or unreadable, and the whole account while its
/// learner list is, contributes nothing (not locked) until they arrive.
final accountLockHistoriesProvider = Provider<List<LearnerSettingsHistory>>((
  ref,
) {
  final scopes = ref.watch(lockDrivingScopesProvider);
  if (scopes.hasError || !scopes.hasValue) return const [];
  return [
    for (final scope in scopes.requireValue)
      ?ref.watch(learnerLockSettingsProvider(scope)).value,
  ];
});

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
