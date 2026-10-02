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
/// The union of `lockWindows` over every learner whose lock drives this
/// device ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the overlay, notification suppression and the Mishna history all read
/// this one value. A learner whose settings are loading or unreadable is
/// judged fail-closed. Re-judged at the next lock boundary (exactly) and
/// at least every [sacredWindowRecheck], so the overlay appears at the
/// lock's start and lifts just after its end without any other input
/// changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.
@Riverpod(keepAlive: true)
class CurrentSacredWindow extends _$CurrentSacredWindow {
  Timer? _timer;

  @override
  SacredWindow? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final histories = ref.watch(accountLockHistoriesProvider);
    final clock = ref.watch(localDayClockProvider);
    _schedule(histories, clock.nowUtc());
    return sacredWindowAt(histories, clock.nowUtc());
  }

  void _schedule(List<LearnerSettingsHistory> histories, DateTime now) {
    _timer?.cancel();
    final next = nextLockChange(histories, now);
    var wait = next == null ? sacredWindowRecheck : next.difference(now);
    if (wait > sacredWindowRecheck) wait = sacredWindowRecheck;
    if (wait < Duration.zero) wait = Duration.zero;
    _timer = Timer(wait, _tick);
  }

  void _tick() {
    final histories = ref.read(accountLockHistoriesProvider);
    final now = ref.read(localDayClockProvider).nowUtc();
    final next = sacredWindowAt(histories, now);
    if (next != state) state = next;
    _schedule(histories, now);
  }
}
