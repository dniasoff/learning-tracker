import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/zmanim_window_service.dart';

void main() {
  group('ZmanimWindowService', () {
    const service = ZmanimWindowService();

    // Lakewood, NJ — 40.0959, -74.2222
    const lakewoodLat = 40.0959;
    const lakewoodLong = -74.2222;

    // Jerusalem — 31.7964, 35.2454
    const jerusalemLat = 31.7964;
    const jerusalemLong = 35.2454;

    test('emits a window covering Shabbos in Lakewood', () {
      // Pick a known Shabbos: Friday May 1 2026 → Saturday May 2 2026.
      final from = DateTime(2026, 5, 1);
      final windows = service.computeWindows(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        inIsrael: false,
        from: from,
        span: const Duration(days: 7),
      );
      expect(windows, isNotEmpty);
      // Find the window that covers Saturday at noon.
      final saturdayNoon = DateTime(2026, 5, 2, 12).toUtc();
      final covering = windows.where(
        (w) =>
            !saturdayNoon.isBefore(w.startUtc) &&
            !saturdayNoon.isAfter(w.endUtc),
      );
      expect(
        covering,
        isNotEmpty,
        reason: 'expected a Shabbos window covering Sat noon',
      );
      final w = covering.first;
      // Friday CL is in the late afternoon Friday local; should be > Friday noon.
      expect(w.startUtc.isAfter(DateTime(2026, 5, 1, 12).toUtc()), isTrue);
      // End should be before Sunday morning.
      expect(w.endUtc.isBefore(DateTime(2026, 5, 3, 6).toUtc()), isTrue);
      expect(w.kind, SacredWindowKind.shabbos);
    });

    test('chains Erev Shabbos + Shabbos + first day Pesach (chu"l)', () {
      // 2026 Pesach: 1st seder night = Wed Apr 1 2026; 1st day Pesach = Apr 2;
      // 2nd day = Apr 3 (Friday); Shabbos = Apr 4. So in chu"l we get a long
      // chain: Wed eve → Sat night.
      final windows = service.computeWindows(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        inIsrael: false,
        from: DateTime(2026, 3, 30),
        span: const Duration(days: 14),
      );
      // The Pesach-into-Shabbos window must include both Apr 3 (Fri YT2)
      // and Apr 4 (Shabbos).
      final fridayNoon = DateTime(2026, 4, 3, 12).toUtc();
      final saturdayNoon = DateTime(2026, 4, 4, 12).toUtc();
      final spanning = windows.where(
        (w) =>
            !fridayNoon.isBefore(w.startUtc) && !saturdayNoon.isAfter(w.endUtc),
      );
      expect(
        spanning,
        isNotEmpty,
        reason: 'expected a chained YT/Shabbos window over Apr 3-4 2026',
      );
      expect(
        spanning.first.kind,
        anyOf(SacredWindowKind.shabbosYomTov, SacredWindowKind.yomTov),
      );
    });

    test('Israel: 1-day Pesach not chained where chu"l would be', () {
      // Same dates as above. In Israel only Apr 2 is YT (1st day) and Apr 3 is
      // chol hamoed (not blocked). Apr 4 is Shabbos. So we get *separate*
      // windows for Apr 2 and Apr 4 — no Apr 3 chain.
      final windows = service.computeWindows(
        latitude: jerusalemLat,
        longitude: jerusalemLong,
        inIsrael: true,
        from: DateTime(2026, 3, 30),
        span: const Duration(days: 10),
      );
      final friday = DateTime(2026, 4, 3, 12).toUtc();
      final coveringFriday = windows.where(
        (w) => !friday.isBefore(w.startUtc) && !friday.isAfter(w.endUtc),
      );
      expect(
        coveringFriday,
        isEmpty,
        reason: 'Apr 3 2026 is chol hamoed in Israel; should not be blocked',
      );
    });

    test('15-min cushion is applied on both edges', () {
      const cushion = 15;
      final windows = service.computeWindows(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        inIsrael: false,
        from: DateTime(2026, 5, 1),
        span: const Duration(days: 7),
        cushionMin: cushion,
      );
      final shabbosWindow = windows.first;
      // With cushion=0 the window should be exactly cushion minutes shorter.
      final noCushion = service.computeWindows(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        inIsrael: false,
        from: DateTime(2026, 5, 1),
        span: const Duration(days: 7),
        cushionMin: 0,
      );
      expect(
        shabbosWindow.startUtc,
        noCushion.first.startUtc.subtract(const Duration(minutes: cushion)),
      );
      expect(
        shabbosWindow.endUtc,
        noCushion.first.endUtc.add(const Duration(minutes: cushion)),
      );
    });

    test('Yom Kippur emits a yomKippur-kind window', () {
      // YK 2026: Tishrei 10 5787 = Mon Sep 21 2026.
      // Erev YK starts at sunset Sun Sep 20.
      final windows = service.computeWindows(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        inIsrael: false,
        from: DateTime(2026, 9, 18),
        span: const Duration(days: 7),
      );
      final ykNoon = DateTime(2026, 9, 21, 12).toUtc();
      final covering = windows.where(
        (w) => !ykNoon.isBefore(w.startUtc) && !ykNoon.isAfter(w.endUtc),
      );
      expect(covering, isNotEmpty);
      expect(covering.first.kind, SacredWindowKind.yomKippur);
    });
  });
}
