// Story 4.3 (DNI-511) AC-8: at 840dp and wider My talmidim sets the list
// (5 columns) beside the selected learner (7 columns); the selection is kept
// as the grant list updates, and cleared the moment its grant leaves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_roster_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/my_talmidim_screen.dart';

import '../talmidim_fixtures.dart';

void main() {
  late FakeTalmidInputs inputs;
  late RecordingTalmidOpener opener;

  setUp(() {
    inputs = FakeTalmidInputs();
    opener = RecordingTalmidOpener();
    for (var n = 1; n <= 3; n++) {
      inputs.states[talmidScope(n)] = AsyncData(talmidState(sub: rebbeTrack()));
    }
  });

  Future<void> refreshRoster(WidgetTester tester) async {
    ProviderScope.containerOf(
      tester.element(find.byType(MyTalmidimScreen)),
    ).invalidate(talmidRosterProvider);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Expanded flexOf(WidgetTester tester, int flex) => tester.widget<Expanded>(
    find.byWidgetPredicate((w) => w is Expanded && w.flex == flex),
  );

  testWidgets('at 840dp: list (5) beside the selected learner (7); a tap '
      'selects in place', (tester) async {
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [
          talmidEntry(1, name: 'Avraham Stein'),
          talmidEntry(2, name: 'Moshe Levi'),
        ],
      ]),
      inputs: inputs,
      opener: opener,
      size: const Size(840, 900),
    );
    expect(flexOf(tester, 5), isNotNull);
    expect(flexOf(tester, 7), isNotNull);
    expect(find.byKey(const Key('talmidimSelectPrompt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('talmidRow-grant-2')));
    await tester.pump();
    expect(opener.calls, isEmpty, reason: 'a tablet tap selects, not opens');
    expect(
      tester.widget<Text>(find.byKey(const Key('talmidDetailName'))).data,
      'Moshe Levi',
    );
    final row = tester.widget<Material>(
      find.byKey(const Key('talmidRow-grant-2')),
    );
    expect((row.shape! as RoundedRectangleBorder).side.width, 2);

    // The pane opens the learner through the opener (the PIN gate).
    await tester.tap(find.byKey(const Key('talmidDetailOpen')));
    await tester.pump();
    expect(opener.calls, [('grant-2', null)]);
  });

  testWidgets('the selection is kept while its grant stays, and cleared '
      'when it leaves', (tester) async {
    final repo = ScriptedTutorRosterRepository([
      [
        talmidEntry(1, name: 'Avraham Stein'),
        talmidEntry(2, name: 'Moshe Levi'),
      ],
      [
        talmidEntry(1, name: 'Avraham Stein'),
        talmidEntry(2, name: 'Moshe Levi'),
        talmidEntry(3, name: 'Dovid Rosen'),
      ],
      [
        talmidEntry(1, name: 'Avraham Stein'),
        talmidEntry(3, name: 'Dovid Rosen'),
      ],
    ]);
    await pumpTalmidim(
      tester,
      repo: repo,
      inputs: inputs,
      opener: opener,
      size: const Size(1024, 900),
    );
    await tester.tap(find.byKey(const Key('talmidRow-grant-2')));
    await tester.pump();

    // A new grant arrives: Moshe stays selected, the pane in place.
    await refreshRoster(tester);
    expect(find.text('Dovid Rosen'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('talmidDetailName'))).data,
      'Moshe Levi',
    );

    // Moshe's grant leaves: the selection clears, deterministically.
    await refreshRoster(tester);
    expect(find.text('Moshe Levi'), findsNothing);
    expect(find.byKey(const Key('talmidDetailName')), findsNothing);
    expect(find.byKey(const Key('talmidimSelectPrompt')), findsOneWidget);
  });

  testWidgets('a locked talmid cannot be selected', (tester) async {
    inputs.locks[talmidScope(1)] = const AsyncData(true);
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [talmidEntry(1, name: 'Avraham Stein')],
      ]),
      inputs: inputs,
      opener: opener,
      size: const Size(1024, 900),
    );
    await tester.tap(find.byKey(const Key('talmidRowLocked')));
    await tester.pump();
    expect(find.byKey(const Key('talmidimSelectPrompt')), findsOneWidget);
  });

  testWidgets('below 840dp: one pane, a tap opens the learner', (tester) async {
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [talmidEntry(1, name: 'Avraham Stein')],
      ]),
      inputs: inputs,
      opener: opener,
      size: const Size(839, 900),
    );
    expect(find.byKey(const Key('talmidimSelectPrompt')), findsNothing);
    await tester.tap(find.byKey(const Key('talmidRow-grant-1')));
    await tester.pump();
    expect(opener.calls, [('grant-1', null)]);
  });
}
