// Story 2.7 (DNI-498) AC-3 and search edge cases, widget level (the pure
// rules are in test/features/sub_tracks/domain/ground_selection_test.dart):
// parent selection, ground already in this sub-track, in use elsewhere and
// learnt, Available only with its exact empty copy, Reset changes, search.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_tree.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

SubTrack _school([List<NodeEntry> ground = const []]) => fixtureTrack(
  schoolId,
  'School',
  curriculumId: engineCurriculum,
  ground: ground,
);

SubTrack _rebbe(List<NodeEntry> ground) => fixtureTrack(
  rebbeId,
  'Rebbe',
  curriculumId: engineCurriculum,
  ground: ground,
);

Future<GroundPickerWorld> _pump(
  WidgetTester tester, {
  List<SubTrack>? tracks,
  Set<String> learnt = const {},
}) async {
  final world = GroundPickerWorld(
    corpus: mishnayosCorpus(),
    commands: FakeLearningCommands(),
    tracks: tracks ?? [_school()],
    learnt: learnt,
  );
  addTearDown(world.dispose);
  tester.view.physicalSize = phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      child: Scaffold(
        body: GroundPickerPane(subTrackId: schoolId, onClose: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

Finder _row(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

Checkbox _box(WidgetTester tester, String name) => tester.widget<Checkbox>(
  find.descendant(of: _row(name), matching: find.byType(Checkbox)),
);

Future<void> _expand(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    await tester.tap(find.byTooltip('Expand $name'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('selecting a parent selects its descendants', (tester) async {
    await _pump(tester);
    await tester.tap(
      find.descendant(
        of: _row('Seder Zeraim'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester, ['Seder Zeraim', 'Mishnah Berakhot']);
    for (final name in [
      'Seder Zeraim',
      'Mishnah Berakhot',
      'Mishnah Berakhot 1',
      'Mishnah Peah',
    ]) {
      expect(_box(tester, name).value, isTrue, reason: name);
    }
    expect(_box(tester, 'Seder Moed').value, isFalse);
    expect(find.text('Add 1 Seder to School'), findsOneWidget);
  });

  testWidgets('ground already in this sub-track is pre-checked and disabled, '
      'a child of a stored ancestor included', (tester) async {
    await _pump(
      tester,
      tracks: [
        _school(const [berakhot]),
      ],
    );
    await _expand(tester, ['Seder Zeraim', 'Mishnah Berakhot']);
    for (final name in ['Mishnah Berakhot', 'Mishnah Berakhot 2']) {
      final box = _box(tester, name);
      expect(box.value, isTrue, reason: name);
      expect(box.onChanged, isNull, reason: name);
    }
    expect(find.text('Already in School'), findsNWidgets(3));
    // The seder is still selectable for its other masechta.
    expect(_box(tester, 'Seder Zeraim').onChanged, isNotNull);
  });

  testWidgets('ground in use elsewhere stays selectable and is tagged', (
    tester,
  ) async {
    await _pump(
      tester,
      tracks: [
        _school(),
        _rebbe(const [peah]),
      ],
    );
    await _expand(tester, ['Seder Zeraim']);
    expect(
      find.descendant(
        of: _row('Mishnah Peah'),
        matching: find.text('Rebbe · In use'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: _row('Mishnah Peah'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(_box(tester, 'Mishnah Peah').value, isTrue);
    expect(find.text('Add 1 Masechta to School'), findsOneWidget);
  });

  testWidgets('learnt ground stays selectable and is tagged Chazara', (
    tester,
  ) async {
    await _pump(tester, learnt: {...mishnayosCorpus().leavesUnder(berakhot2)});
    await _expand(tester, ['Seder Zeraim', 'Mishnah Berakhot']);
    expect(
      find.descendant(
        of: _row('Mishnah Berakhot 2'),
        matching: find.text('Chazara'),
      ),
      findsOneWidget,
    );
    expect(_box(tester, 'Mishnah Berakhot 2').onChanged, isNotNull);
  });

  testWidgets('Available only hides in-use and learnt ground', (tester) async {
    await _pump(
      tester,
      tracks: [
        _school(),
        _rebbe(const [peah]),
      ],
      learnt: {...mishnayosCorpus().leavesUnder(berakhot)},
    );
    await tester.tap(find.text('Available only'));
    await tester.pumpAndSettle();
    // All of Zeraim is learnt or in use; Moed is left.
    expect(find.text('Seder Zeraim'), findsNothing);
    expect(find.text('Seder Moed'), findsOneWidget);
  });

  testWidgets('Available only with nothing left shows the exact copy', (
    tester,
  ) async {
    await _pump(
      tester,
      tracks: [
        _school(const [zeraim]),
      ],
      learnt: {...mishnayosCorpus().leavesUnder(moed)},
    );
    await tester.tap(find.text('Available only'));
    await tester.pumpAndSettle();
    expect(
      find.text('Everything here is already assigned or learnt.'),
      findsOneWidget,
    );
    expect(find.byType(GroundPickerTree), findsOneWidget);
  });

  testWidgets('Reset changes clears only the pending selection', (
    tester,
  ) async {
    await _pump(
      tester,
      tracks: [
        _school(const [berakhot1]),
      ],
    );
    await tester.tap(
      find.descendant(of: _row('Seder Moed'), matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add 1 Seder to School'), findsOneWidget);
    await tester.tap(find.text('Reset changes'));
    await tester.pumpAndSettle();
    expect(find.text('Add to School'), findsOneWidget);
    expect(_box(tester, 'Seder Moed').value, isFalse);
    await _expand(tester, ['Seder Zeraim', 'Mishnah Berakhot']);
    expect(_box(tester, 'Mishnah Berakhot 1').value, isTrue);
    expect(_box(tester, 'Mishnah Berakhot 1').onChanged, isNull);
  });

  testWidgets('search keeps the match path visible; no match says so', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'PEAH');
    await tester.pumpAndSettle();
    expect(find.text('Seder Zeraim'), findsOneWidget);
    expect(find.text('Mishnah Peah'), findsOneWidget);
    expect(find.text('Mishnah Peah 1'), findsOneWidget);
    expect(find.text('Seder Moed'), findsNothing);
    expect(find.text('Mishnah Berakhot'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches “zzz”.'), findsOneWidget);
  });
}
