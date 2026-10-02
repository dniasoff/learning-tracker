// DNI-497 (Story 2.6) AC-2: capacity vs path and the audience-specific
// shortfall tag.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capacity_bar.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../sub_track_detail_harness.dart';

SubTrackDetail _detail({
  required SubTrackDetailRole role,
  int? capacity,
  int shortfall = 0,
  int remaining = 0,
}) {
  final track = detailSubTrack(10, 'School', const [berakhot]);
  return SubTrackDetail(
    track: track,
    role: role,
    state: SubTrackState(
      subTrackId: track.id,
      holdsGround: true,
      inForecast: capacity != null,
      onHome: true,
      remainingPath: [
        for (var i = 0; i < remaining; i++) 'Mishnah Berakhot 1:$i',
      ],
      capacity: capacity,
      shortfall: shortfall,
    ),
    ground: SubTrackGroundProjection.project(
      track: track,
      ground: track.ground,
      corpus: mishnayosCorpus(),
      learntLeaves: const {},
      countedLearns: const [],
      subTracks: [track],
      holdsGround: (_) => true,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  SubTrackDetail detail, {
  VoidCallback? onSetDeadline,
}) => tester.pumpWidget(
  pumpApp(
    child: Scaffold(
      body: SubTrackCapacityBar(detail: detail, onSetDeadline: onSetDeadline),
    ),
  ),
);

void main() {
  testWidgets('with a deadline: the exact labels, the engine values and a '
      '6dp bar', (tester) async {
    await _pump(
      tester,
      _detail(role: SubTrackDetailRole.parent, capacity: 9, remaining: 5),
    );
    expect(find.text('Capacity vs Path'), findsOneWidget);
    expect(find.text('5 / 9'), findsOneWidget);
    expect(find.text('Remaining path: 5 · Total capacity: 9'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('subTrackCapacityBarTrack'))),
      isA<Size>().having((s) => s.height, 'height', 6),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(5 / 9, 1e-9));
  });

  testWidgets('zero shortfall reads "No shortfall" in the success token', (
    tester,
  ) async {
    for (final role in SubTrackDetailRole.values) {
      await _pump(tester, _detail(role: role, capacity: 9, remaining: 3));
      expect(find.text('No shortfall'), findsOneWidget, reason: '$role');
      expect(find.byKey(const ValueKey('subTrackShortfallTag')), findsNothing);
      _expectTagColor(
        tester,
        'subTrackNoShortfallTag',
        (c) => c.statusSuccessSoftBg,
      );
    }
  });

  testWidgets('a positive shortfall: the parent sees the count in a warning '
      'tag; the child sees only the bar and caption', (tester) async {
    await _pump(
      tester,
      _detail(
        role: SubTrackDetailRole.parent,
        capacity: 4,
        remaining: 7,
        shortfall: 3,
      ),
    );
    expect(find.text('Shortfall: 3'), findsOneWidget);
    expect(find.text('No shortfall'), findsNothing);
    _expectTagColor(tester, 'subTrackShortfallTag', (c) => c.statusWarningSoft);

    await _pump(
      tester,
      _detail(
        role: SubTrackDetailRole.child,
        capacity: 4,
        remaining: 7,
        shortfall: 3,
      ),
    );
    expect(find.text('7 / 4'), findsOneWidget);
    expect(find.text('Remaining path: 7 · Total capacity: 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('subTrackShortfallTag')), findsNothing);
    expect(find.textContaining('3'), findsNothing);
    expect(find.text('No shortfall'), findsNothing);
  });

  testWidgets('no deadline hides the bar; the parent sees the Story 2.4 note '
      'and its link', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      _detail(role: SubTrackDetailRole.parent, remaining: 5),
      onSetDeadline: () => opened++,
    );
    expect(find.byKey(const ValueKey('subTrackCapacityBar')), findsNothing);
    expect(
      find.text(
        "Without a deadline, a sub-track can't lower the daily target.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Set a deadline'));
    expect(opened, 1);

    await _pump(tester, _detail(role: SubTrackDetailRole.child, remaining: 5));
    expect(find.byKey(const ValueKey('subTrackNoDeadlineNote')), findsNothing);
    expect(find.byKey(const ValueKey('subTrackCapacityBar')), findsNothing);
  });
}

void _expectTagColor(
  WidgetTester tester,
  String key,
  Color Function(AppPalette colors) token,
) {
  final finder = find.byKey(ValueKey(key));
  final box =
      tester
              .widget<Container>(
                find.descendant(of: finder, matching: find.byType(Container)),
              )
              .decoration!
          as BoxDecoration;
  expect(box.color, token(tester.element(finder).colors));
}
