/// Which lock-ignored events this device has already told the learner
/// about (Story 3.1, DNI-504 AC-9; UX-DR-107).
///
/// A per-device convenience, not learning data: the events stay in
/// `learning_events` and the engine decides what is lock-ignored
/// (`LearnerState.lockIgnoredEventIds`, AD-36). This only remembers which
/// of those ids the Learn tab has announced, per learner, so the "kept,
/// not counted" snackbar shows once per event rather than on every launch.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the lock-ignored event ids already announced, per learner.
abstract interface class LockIgnoredNoticeStore {
  /// The ids already announced for [scope]; empty when none (or unreadable).
  Future<Set<String>> announced(LearnerScope scope);

  /// Records [ids] as the announced set for [scope], replacing the old one
  /// (the engine's current lock-ignored set, so it never grows unbounded).
  Future<void> setAnnounced(LearnerScope scope, Set<String> ids);
}

/// [LockIgnoredNoticeStore] over `SharedPreferences`.
final class SharedPreferencesLockIgnoredNoticeStore
    implements LockIgnoredNoticeStore {
  /// Creates the store.
  const SharedPreferencesLockIgnoredNoticeStore();

  static String _key(LearnerScope scope) =>
      'lock_ignored_announced.${scope.ownerUid}.${scope.profileId}';

  @override
  Future<Set<String>> announced(LearnerScope scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {...?prefs.getStringList(_key(scope))};
    } on Exception {
      // Unreadable: announce again rather than never.
      return const {};
    }
  }

  @override
  Future<void> setAnnounced(LearnerScope scope, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(scope), (ids.toList()..sort()));
    } on Exception {
      // Best effort: at worst the notice shows once more.
    }
  }
}

/// The store the Learn tab's lock-ignored notice uses.
final lockIgnoredNoticeStoreProvider = Provider<LockIgnoredNoticeStore>(
  (ref) => const SharedPreferencesLockIgnoredNoticeStore(),
);
