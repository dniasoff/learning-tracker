// DNI-497 (Story 2.6) AC-3 / AC-4: the ground reflects all-source state
// without moving this source's position; groundless state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_ground_row.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_ground_tree.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

Future<List<String>> _pump(WidgetTester tester, SubTrackDetail detail) async {
  final opened = <String>[];
  await tester.pumpWidget(
    pumpApp(
      overrides: rawLabelOverrides(),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SubTrackGroundTree(detail: detail, onOpenLeaf: opened.add),
        ),
      ),
    ),
  );
  return opened;
}

Finder _row(int depth, String ref) =>
    find.byKey(ValueKey('subTrackGroundRow:$depth:$ref'));

Finder _label(String ref) => find.byKey(ValueKey('subTrackGroundLabel:$ref'));

String _semantics(WidgetTester tester, String ref) =>
    tester.getSemantics(find.byKey(ValueKey('subTrackTriState:$ref'))).label;

void main() {
  final school = detailSubTrack(10, 'School', const [berakhot, peah, shabbat]);
  final rebbe = detailSubTrack(20, 'Rebbe', const [shabbat]);

  SubTrackDetail detail() => engineDetail(
    school,
    others: [rebbe],
    events: [
      engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
      engineLearn(2, 'Mishnah Berakhot 2:1'),
      engineLearn(3, 'Mishnah Peah 1:1'),
      engineLearn(4, 'Mishnah Peah 1:2'),
      engineLearn(5, 'Mishnah Shabbat 1:1', source: rebbe.id),
    ],
  );

  testWidgets('complete, partial and empty rows with counts, 12% tint and '
      'tri-state announcements', (tester) async {
    await _pump(tester, detail());
    expect(_row(0, 'Mishnah Berakhot'), findsOneWidget);
    expect(find.text('2 of 5 learnt'), findsOneWidget);
    expect(find.text('2 of 2 learnt • learnt at home'), findsOneWidget);
    expect(find.text('1 of 2 learnt • learnt at Rebbe'), findsOneWidget);

    expect(_semantics(tester, 'Mishnah Berakhot'), 'partially learnt, 2 of 5');
    expect(_semantics(tester, 'Mishnah Peah'), 'complete');

    final colors = tester.element(_row(0, 'Mishnah Peah')).colors;
    final peahBox =
        tester.widget<Container>(_row(0, 'Mishnah Peah')).decoration!
            as BoxDecoration;
    expect(
      peahBox.color,
      Color.alphaBlend(
        colors.brandBlue.withValues(alpha: 0.12),
        colors.brandCreamCard,
      ),
    );
  });

  testWidgets('a non-leaf label expands with 20dp per depth; a leaf label '
      'opens its history', (tester) async {
    final opened = await _pump(tester, detail());
    expect(_row(1, 'Mishnah Berakhot 1'), findsNothing);

    await tester.tap(_label('Mishnah Berakhot'));
    await tester.pumpAndSettle();
    expect(_row(1, 'Mishnah Berakhot 1'), findsOneWidget);
    expect(find.text('1 of 3 learnt'), findsOneWidget);

    await tester.tap(_label('Mishnah Berakhot 1'));
    await tester.pumpAndSettle();
    expect(_row(2, 'Mishnah Berakhot 1:1'), findsOneWidget);
    double indent(int depth, String ref) =>
        (tester
                    .widget<Padding>(
                      find.byKey(ValueKey('subTrackGroundIndent:$depth:$ref')),
                    )
                    .padding
                as EdgeInsetsDirectional)
            .start;
    expect(indent(0, 'Mishnah Berakhot'), 0);
    expect(indent(1, 'Mishnah Berakhot 1'), subTrackGroundIndentPerDepth);
    expect(indent(2, 'Mishnah Berakhot 1:1'), 40);

    await tester.tap(_label('Mishnah Berakhot 1:2'));
    expect(opened, ['Mishnah Berakhot 1:2']);

    // Collapsing hides the subtree again.
    await tester.tap(_label('Mishnah Berakhot'));
    await tester.pumpAndSettle();
    expect(_row(1, 'Mishnah Berakhot 1'), findsNothing);
  });

  testWidgets('a leaf learnt elsewhere renders learnt and labelled, and does '
      "not move this track's position", (tester) async {
    final d = detail();
    expect(d.upNext, 'Mishnah Berakhot 1:2', reason: 'engine position');
    expect(d.ticked, 1);
    await _pump(tester, d);
    await tester.tap(_label('Mishnah Berakhot'));
    await tester.pumpAndSettle();
    await tester.tap(_label('Mishnah Berakhot 2'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _row(2, 'Mishnah Berakhot 2:1'),
        matching: find.text('1 of 1 learnt • learnt at home'),
      ),
      findsOneWidget,
    );
    expect(_semantics(tester, 'Mishnah Berakhot 2:1'), 'complete');
  });

  testWidgets('ground also held by another non-ended track shows "{name} · '
      'In use"', (tester) async {
    final ended = detailSubTrack(30, 'Old', const [peah], ended: true);
    await _pump(tester, engineDetail(school, others: [rebbe, ended]));
    expect(find.text('Rebbe · In use'), findsOneWidget);
    expect(find.text('Old · In use'), findsNothing);
    expect(
      find.byKey(const ValueKey('subTrackInUse:Mishnah Shabbat:Rebbe')),
      findsOneWidget,
    );
  });

  testWidgets('a groundless sub-track shows the groundless state and no '
      'Add ground action (AC-4)', (tester) async {
    await _pump(tester, engineDetail(detailSubTrack(40, 'New', const [])));
    expect(find.byKey(const ValueKey('subTrackGroundless')), findsOneWidget);
    expect(find.text('No ground yet'), findsOneWidget);
    expect(find.textContaining('Add ground'), findsNothing);
  });
}
