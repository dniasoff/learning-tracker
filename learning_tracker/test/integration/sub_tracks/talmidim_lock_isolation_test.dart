// Story 4.3 (DNI-511) AC-4 (integration): a locked talmid is private
// without locking the tutor's device.
//
// Real lock path end to end: each talmid's own settings history (no
// location, so the AD-36 fail-closed Fri 12:00 → Sun 01:00 learner-local
// window), the shared CaptureGate, and the device's SacredTimeLockOverlay
// driven by the tutor account's OWN profile. At Fri 2026-09-04 12:00Z the
// Jerusalem talmid is inside his window (15:00 local) while the tutor's own
// Los Angeles profile and the second talmid are not (05:00 local).
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

final _now = DateTime.utc(2026, 9, 4, 12);

final _jerusalemNoLocation = constantHistory(
  lockSettings(timeZone: 'Asia/Jerusalem'),
);
final _losAngelesNoLocation = constantHistory(
  lockSettings(timeZone: 'America/Los_Angeles'),
);

void main() {
  testWidgets('the locked talmid row is redacted and inert; the other row '
      'stays usable; the device overlay stays down', (tester) async {
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
            scope == talmidScope(1)
                ? _jerusalemNoLocation
                : _losAngelesNoLocation,
          ),
        ),
        // The device lock: the tutor account's own profile only.
        accountLockHistoriesProvider.overrideWithValue([_losAngelesNoLocation]),
      ],
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // The locked talmid: only "Shabbos / Yom Tov" — no name, initials,
    // status, position or action.
    expect(find.text('Shabbos / Yom Tov'), findsOneWidget);
    expect(find.text('Avraham Stein'), findsNothing);
    expect(find.text('AS'), findsNothing);
    expect(find.byKey(const Key('talmidRow-grant-1')), findsNothing);
    expect(find.byKey(const Key('talmidStatusChip-grant-1')), findsNothing);
    expect(find.byKey(const Key('talmidAddGround-grant-1')), findsNothing);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Shabbos / Yom Tov'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Avraham')), findsNothing);
    handle.dispose();

    // Tapping it opens nothing.
    await tester.tap(find.byKey(const Key('talmidRowLocked')));
    await tester.pump();
    expect(opener.calls, isEmpty);

    // The second talmid stays live and usable.
    expect(find.text('Moshe Levi'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    await tester.tap(find.byKey(const Key('talmidRow-grant-2')));
    await tester.pump();
    expect(opener.calls, [('grant-2', null)]);

    // The tutor device's own overlay is untouched by the talmid's lock.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyTalmidimScreen)),
    );
    expect(container.read(currentSacredWindowProvider), isNull);
    expect(container.read(currentTutoredSacredWindowProvider), isNull);
    expect(container.read(activeTutoredProfileSelectionProvider), isNull);
  });
}
