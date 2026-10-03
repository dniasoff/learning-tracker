// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/ground_picker_row.dart`
// (Story 2.7 / DNI-498 AC-3, AC-9): the progress mark and the selection
// checkbox are separate and each is spoken; stored ground is disabled; the
// tags name the holder, learnt ground and this sub-track.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_row.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';

GroundRowState _state({
  TriState progress = TriState.empty,
  bool inThisTrack = false,
  List<String> inUseBy = const [],
  GroundSelectionMark mark = GroundSelectionMark.unchecked,
}) => GroundRowState(
  node: berakhot,
  childCount: 2,
  leafCount: 5,
  progress: progress,
  inThisTrack: inThisTrack,
  inUseBy: inUseBy,
  mark: mark,
);

Future<int> _pump(WidgetTester tester, GroundRowState state) async {
  var toggles = 0;
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(
        body: GroundPickerRow(
          state: state,
          depth: 1,
          name: 'Berachos',
          trackName: 'School',
          countText: '2 Perakim',
          expanded: false,
          onToggleExpanded: () {},
          onToggleSelected: () => toggles++,
        ),
      ),
    ),
  );
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  return toggles;
}

void main() {
  testWidgets('a partly learnt, partly picked row speaks both states', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final toggles = await _pump(
      tester,
      _state(progress: TriState.partial, mark: GroundSelectionMark.partial),
    );
    expect(toggles, 1);
    expect(
      find.bySemanticsLabel(RegExp('Berachos, 2 Perakim, Partial')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Partly selected'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
    handle.dispose();
  });

  testWidgets('stored ground is checked, disabled and tagged', (tester) async {
    final toggles = await _pump(
      tester,
      _state(inThisTrack: true, mark: GroundSelectionMark.checked),
    );
    expect(toggles, 0);
    final box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.value, isTrue);
    expect(box.onChanged, isNull);
    expect(find.text('Already in School'), findsOneWidget);
  });

  testWidgets('in use and Chazara tags keep the row selectable', (
    tester,
  ) async {
    final toggles = await _pump(
      tester,
      _state(progress: TriState.complete, inUseBy: const ['Rebbe', 'Shiur']),
    );
    expect(toggles, 1);
    expect(find.text('Rebbe · In use'), findsOneWidget);
    expect(find.text('Shiur · In use'), findsOneWidget);
    expect(find.text('Chazara'), findsOneWidget);
  });
}
