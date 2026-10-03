/// Whether a Sacred Time lock cover is on screen (DNI-481 AC-1/AC-2).
///
/// The lock covers (`SacredTimeLockOverlay`, `TutoredLearnerLockOverlay`)
/// engage the moment their lock starts and release only after the lock has
/// ended AND they have discarded every root snack bar and material banner
/// requested while they were up. Anything that must surface after a lock
/// (the after-lock location prompt) waits for [lockCoverEngagedProvider]
/// to turn false, so it is shown after that discard and never swept by it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The lock covers currently engaged, by an identity token per cover.
final lockCoversProvider = NotifierProvider<LockCovers, Set<Object>>(
  LockCovers.new,
);

/// Whether any lock cover is engaged (shown, or still releasing).
final lockCoverEngagedProvider = Provider<bool>(
  (ref) => ref.watch(lockCoversProvider).isNotEmpty,
);

/// The registry of engaged lock covers.
class LockCovers extends Notifier<Set<Object>> {
  @override
  Set<Object> build() => const {};

  /// Marks the cover [token] engaged.
  void engage(Object token) {
    if (!ref.mounted || state.contains(token)) return;
    state = {...state, token};
  }

  /// Marks the cover [token] released.
  void release(Object token) {
    if (!ref.mounted || !state.contains(token)) return;
    state = {...state}..remove(token);
  }
}
