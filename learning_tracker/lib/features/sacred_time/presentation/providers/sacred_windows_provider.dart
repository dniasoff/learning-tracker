import 'dart:async';

import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/sacred_lock.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sacred_windows_provider.g.dart';

/// The longest the lock state goes unre-judged; a lock boundary closer
/// than this is met exactly.
const Duration sacredWindowRecheck = Duration(minutes: 1);

/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner profile of the signed-in
/// account ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the app-wide overlay, notification suppression and the Mishna history
/// all read this one value. A tutored talmid never drives it (see
/// [CurrentTutoredSacredWindow]). A learner whose settings are loading or
/// unreadable is judged fail-closed. Re-judged at the next lock boundary
/// (exactly) and at least every [sacredWindowRecheck], so the overlay
/// appears at the lock's start and lifts just after its end without any
/// other input changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.
@Riverpod(keepAlive: true)
class CurrentSacredWindow extends _$CurrentSacredWindow {
  final _LockBoundaryTimer _timer = _LockBoundaryTimer();

  @override
  SacredWindow? build() {
    ref.onDispose(_timer.cancel);
    final histories = ref.watch(accountLockHistoriesProvider);
    final now = ref.watch(localDayClockProvider).nowUtc();
    _timer.schedule(histories, now, _tick);
    return sacredWindowAt(histories, now);
  }

  void _tick() {
    final histories = ref.read(accountLockHistoriesProvider);
    final now = ref.read(localDayClockProvider).nowUtc();
    final next = sacredWindowAt(histories, now);
    if (next != state) state = next;
    _timer.schedule(histories, now, _tick);
  }
}

/// The lock of the talmid an active tutored session shows, or null when
/// no tutored session is active or that talmid is not locked (DNI-481
/// AC-1 tutor rule, AD-36).
///
/// Judged from [tutoredLearnerLockHistoryProvider] (fail-closed while the
/// talmid's settings load or cannot be read) with the same [sacredWindowAt]
/// as the device lock, and re-judged at the talmid's lock boundaries. It
/// covers only the talmid's screens: it never feeds the account lock, the
/// notification predicate or the after-lock prompt.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the cover appears and lifts on time.
@Riverpod(keepAlive: true)
class CurrentTutoredSacredWindow extends _$CurrentTutoredSacredWindow {
  final _LockBoundaryTimer _timer = _LockBoundaryTimer();

  @override
  SacredWindow? build() {
    ref.onDispose(_timer.cancel);
    final histories = _histories(ref.watch(tutoredLearnerLockHistoryProvider));
    if (histories.isEmpty) {
      _timer.cancel();
      return null;
    }
    final now = ref.watch(localDayClockProvider).nowUtc();
    _timer.schedule(histories, now, _tick);
    return sacredWindowAt(histories, now);
  }

  void _tick() {
    final histories = _histories(ref.read(tutoredLearnerLockHistoryProvider));
    final now = ref.read(localDayClockProvider).nowUtc();
    final next = sacredWindowAt(histories, now);
    if (next != state) state = next;
    if (histories.isNotEmpty) _timer.schedule(histories, now, _tick);
  }

  static List<LearnerSettingsHistory> _histories(
    LearnerSettingsHistory? talmid,
  ) => [?talmid];
}

/// Re-judges a lock at its next boundary (exactly) and at least every
/// [sacredWindowRecheck].
final class _LockBoundaryTimer {
  Timer? _timer;

  void schedule(
    List<LearnerSettingsHistory> histories,
    DateTime now,
    void Function() tick,
  ) {
    _timer?.cancel();
    final next = nextLockChange(histories, now);
    var wait = next == null ? sacredWindowRecheck : next.difference(now);
    if (wait > sacredWindowRecheck) wait = sacredWindowRecheck;
    if (wait < Duration.zero) wait = Duration.zero;
    _timer = Timer(wait, tick);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
