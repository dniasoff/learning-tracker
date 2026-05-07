import 'dart:async';

import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/zmanim_window_service.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sacred_windows_provider.g.dart';

/// 6-month rolling list of pre-computed Sacred Time block windows. Recomputed
/// whenever the user's location or in-Israel flag changes.
@Riverpod(keepAlive: true)
List<SacredWindow> sacredWindows(Ref ref) {
  final location = ref.watch(sacredLocationProvider);
  final inIsrael = ref.watch(inIsraelProvider);
  if (location == null) return const [];
  const service = ZmanimWindowService();
  return service.computeWindows(
    latitude: location.latitude,
    longitude: location.longitude,
    inIsrael: inIsrael,
    from: DateTime.now(),
    span: const Duration(days: 180),
  );
}

/// Currently-active window (the one whose [start, end] contains "now"), or
/// null if not currently in Sacred Time.
///
/// Recomputed every minute via an internal timer so the lock screen drops
/// without manual invalidation when tzais passes.
@Riverpod(keepAlive: true)
class CurrentSacredWindow extends _$CurrentSacredWindow {
  Timer? _timer;

  @override
  SacredWindow? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    _scheduleNextTick();

    final windows = ref.watch(sacredWindowsProvider);
    return _findActive(windows);
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    // 30-second resolution is plenty for a 15-min-cushioned boundary.
    _timer = Timer(const Duration(seconds: 30), () {
      final windows = ref.read(sacredWindowsProvider);
      final next = _findActive(windows);
      if (next != state) state = next;
      _scheduleNextTick();
    });
  }

  static SacredWindow? _findActive(List<SacredWindow> windows) {
    final nowUtc = DateTime.now().toUtc();
    for (final w in windows) {
      if (!nowUtc.isBefore(w.startUtc) && !nowUtc.isAfter(w.endUtc)) {
        return w;
      }
    }
    return null;
  }
}
