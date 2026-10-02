// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/sub_track_ground_row.dart`
// (DNI-497, AC-3 / AC-8): one tri-state row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_ground_row.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

const peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');

void main() {
  final school = detailSubTrack(10, 'School', const [berakhot, peah1]);
  final rebbe = detailSubTrack(20, 'Rebbe', const [peah1]);
  final detail = engineDetail(
    school,
    others: [rebbe],
    events: [
      engineLearn(1, 'Mishnah Berakhot 1:1'),
      engineLearn(2, 'Mishnah Berakhot 1:2'),
      engineLearn(3, 'Mishnah Berakhot 1:3'),
      engineLearn(4, 'Mishnah Peah 1:1', source: rebbe.id),
      engineLearn(5, 'Mishnah Peah 1:2', source: rebbe.id),
    ],
  );
  final berakhotRow = detail.ground.entries[0];
  final peahRow = detail.ground.entries[1];

  Future<(int, int)> pump(
    WidgetTester tester,
    SubTrackGroundRow row, {
    bool expanded = false,
    Widget? leading,
    Widget? trailing,
  }) async {
    var toggles = 0;
    var opens = 0;
    await tester.pumpWidget(
      pumpApp(
        overrides: rawLabelOverrides(),
        child: Scaffold(
          body: SubTrackGroundRowTile(
            row: row,
            expanded: expanded,
            onToggle: () => toggles++,
            onOpenLeaf: () => opens++,
            leading: leading,
            trailing: trailing,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(ValueKey('subTrackGroundLabel:${row.node.ref}')),
    );
    return (toggles, opens);
  }

  testWidgets('a partial non-leaf row: count, announcement, chevron and '
      'expand on tap', (tester) async {
    final (toggles, opens) = await pump(tester, berakhotRow);
    expect(find.text('3 of 5 learnt • learnt at home'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('subTrackTriState:Mishnah Berakhot')),
          )
          .label,
      'partially learnt, 3 of 5',
    );
    expect(find.byIcon(Icons.remove), findsOneWidget, reason: 'partial dash');
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect((toggles, opens), (1, 0));
  });

  testWidgets('a complete row learnt in another sub-track names it and its '
      '"In use" tag', (tester) async {
    await pump(tester, peahRow);
    expect(find.text('2 of 2 learnt • learnt at Rebbe'), findsOneWidget);
    expect(find.text('Rebbe · In use'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('a leaf opens its history and is indented by its depth', (
    tester,
  ) async {
    final leaf = detail.ground
        .childrenOf(detail.ground.childrenOf(berakhotRow).first)
        .first;
    expect(leaf.depth, 2);
    final (toggles, opens) = await pump(tester, leaf);
    expect((toggles, opens), (0, 1));
    final indent = tester.widget<Padding>(
      find.byKey(ValueKey('subTrackGroundIndent:2:${leaf.node.ref}')),
    );
    expect(
      (indent.padding as EdgeInsetsDirectional).start,
      2 * subTrackGroundIndentPerDepth,
    );
  });

  testWidgets('the parent controls render in the leading and trailing '
      'slots only when given', (tester) async {
    await pump(
      tester,
      peahRow,
      leading: const Icon(Icons.drag_indicator),
      trailing: const Icon(Icons.more_vert),
    );
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await pump(tester, peahRow);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
