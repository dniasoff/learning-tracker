// Mirror test for
// `lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart`
// (DNI-481 AC-1): the device lock is the union over the account's
// learners, appears at the lock start and lifts just after its end.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';

/// A clock that follows fake_async's elapsed time from [start].
final class _FollowingClock implements LocalDayClock {
  _FollowingClock(this.start, this.async);

  final DateTime start;
  final FakeAsync async;

  @override
  DateTime nowUtc() => start.add(async.elapsed);

  @override
  DateTime today() => throw UnimplementedError();
}

void main() {
  final lakewoodH = constantHistory(lakewood);
  final jerusalemH = constantHistory(jerusalem);
  final lock = lockWindows(
    lakewoodH,
    DateTime.utc(2026, 9, 5, 12),
    DateTime.utc(2026, 9, 5, 12),
  ).single;

  test('null on a weekday; the lock with its kind on Shabbos', () {
    final weekday = ProviderContainer.test(
      overrides: [
        accountLockHistoriesProvider.overrideWithValue([lakewoodH]),
        localDayClockProvider.overrideWithValue(
          FakeLocalDayClock(DateTime.utc(2026, 9, 8, 12)),
        ),
      ],
    );
    expect(weekday.read(currentSacredWindowProvider), isNull);

    final shabbos = ProviderContainer.test(
      overrides: [
        accountLockHistoriesProvider.overrideWithValue([jerusalemH, lakewoodH]),
        localDayClockProvider.overrideWithValue(
          FakeLocalDayClock(DateTime.utc(2026, 9, 5, 12)),
        ),
      ],
    );
    expect(
      shabbos.read(currentSacredWindowProvider),
      SacredWindow(
        startUtc: lock.startUtc,
        endUtc: lock.endUtc,
        kind: SacredWindowKind.shabbos,
      ),
    );
  });

  test('appears exactly at the lock start and lifts just after its end', () {
    fakeAsync((async) {
      final start = lock.startUtc.subtract(const Duration(minutes: 3));
      final container = ProviderContainer.test(
        overrides: [
          accountLockHistoriesProvider.overrideWithValue([lakewoodH]),
          localDayClockProvider.overrideWithValue(
            _FollowingClock(start, async),
          ),
        ],
      );
      final seen = <SacredWindow?>[];
      container.listen(
        currentSacredWindowProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      expect(seen, [null]);

      async.elapse(const Duration(minutes: 3) - const Duration(seconds: 1));
      expect(container.read(currentSacredWindowProvider), isNull);
      async.elapse(const Duration(seconds: 1));
      expect(
        container.read(currentSacredWindowProvider)?.startUtc,
        lock.startUtc,
      );

      async.elapse(lock.endUtc.difference(lock.startUtc));
      expect(
        container.read(currentSacredWindowProvider),
        isNotNull,
        reason: 'the end bound is inside the lock',
      );
      async.elapse(const Duration(seconds: 1));
      expect(container.read(currentSacredWindowProvider), isNull);
      container.dispose();
    });
  });
}
