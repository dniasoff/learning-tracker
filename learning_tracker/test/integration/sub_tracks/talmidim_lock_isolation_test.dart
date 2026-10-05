// Product ruling 2026-10-05: a talmid's own Shabbos never stops a tutor
// opening the account. At 2026-09-04 20:00Z Jerusalem is in Shabbos while
// Los Angeles is Friday afternoon and the tutor's own device remains open.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/my_talmidim_screen.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../features/sub_tracks/talmidim_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';

final _now = DateTime.utc(2026, 9, 4, 20);

final _jerusalemLocated = constantHistory(
  lockSettings(
    timeZone: 'Asia/Jerusalem',
    latitude: 31.778,
    longitude: 35.235,
    inIsrael: true,
  ),
);
final _losAngelesLocated = constantHistory(
  lockSettings(
    timeZone: 'America/Los_Angeles',
    latitude: 34.0522,
    longitude: -118.2437,
    inIsrael: false,
  ),
);

void main() {
  testWidgets(
    "a talmid's Shabbos never stops the tutor opening their account",
    (tester) async {
      final inputs = FakeTalmidInputs()
        ..states[talmidScope(1)] = AsyncData(talmidState(sub: rebbeTrack()))
        ..states[talmidScope(2, owner: 2)] = AsyncData(
          talmidState(sub: rebbeTrack()),
        );
      final opener = RecordingTalmidOpener();
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([
          [
            talmidEntry(1, name: 'Avraham Stein'),
            talmidEntry(2, name: 'Moshe Levi', owner: 2),
          ],
        ]),
        inputs: inputs,
        opener: opener,
        realLock: true,
        wrap: (screen) => SacredTimeLockOverlay(child: screen),
        extra: [
          localDayClockProvider.overrideWithValue(FakeLocalDayClock(_now)),
          learnerLockSettingsProvider.overrideWith(
            (ref, scope) => Stream<LearnerSettingsHistory>.value(
              scope == talmidScope(1) ? _jerusalemLocated : _losAngelesLocated,
            ),
          ),
          // Only the tutor's own account history drives the device lock.
          accountLockHistoriesProvider.overrideWithValue([_losAngelesLocated]),
        ],
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('Shabbos / Yom Tov'), findsNothing);
      expect(find.text('Avraham Stein'), findsOneWidget);
      expect(find.byKey(const Key('talmidRow-grant-1')), findsOneWidget);
      expect(find.byKey(const Key('talmidStatusChip-grant-1')), findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Avraham')), findsOneWidget);
      handle.dispose();

      await tester.tap(find.byKey(const Key('talmidRow-grant-1')));
      await tester.pump();
      expect(opener.calls, [('grant-1', null)]);

      // The other talmid stays live and usable too.
      expect(find.text('Moshe Levi'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('talmidRow-grant-2')),
          matching: find.text('On track'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('talmidRow-grant-2')));
      await tester.pump();
      expect(opener.calls, [('grant-1', null), ('grant-2', null)]);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyTalmidimScreen)),
      );
      expect(container.read(currentSacredWindowProvider), isNull);
      expect(container.read(activeTutoredProfileSelectionProvider), isNull);
    },
  );
}
