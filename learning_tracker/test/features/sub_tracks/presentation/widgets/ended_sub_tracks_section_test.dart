// Mirror test for `lib/features/sub_tracks/presentation/widgets/
// ended_sub_tracks_section.dart` (Story 2.8 / DNI-499, AC-5; UX-DR-44,
// UX-DR-70, UX-DR-82): collapsed "Ended sub-tracks ({n})", muted rows,
// never "Completed".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ended_sub_tracks_section.dart';

import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

const _school = '01JHARN0000000000000000001';
const _shiur = '01JHARN0000000000000000002';

final _tracks = [
  // Window passed on 31 Jul 2026 with no write.
  storedSchoolYear(_school, academicYear: 2025),
  SubTrack(
    id: _shiur,
    curriculumId: subTrackTestCurriculum,
    name: 'Shiur',
    type: SubTrackType.ongoing,
    windowStart: '2026-01-01',
    ratePerWeek: 5,
    weeksPerYear: 40,
    learnsOnShabbos: false,
    ground: const [],
    lastChangeId: ulidE,
    endedAt: DateTime.utc(2026, 9, 15, 12),
    endReason: SubTrackEndReason.deleted,
  ),
];

Future<List<String>> _pump(WidgetTester tester, List<SubTrack> tracks) async {
  final opened = <String>[];
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(
        body: ListView(
          children: [
            EndedSubTracksSection(
              tracks: tracks,
              onOpen: (t) => opened.add(t.id),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('absent while nothing has ended', (tester) async {
    await _pump(tester, const []);
    expect(find.byKey(const ValueKey('endedSubTracksGroup')), findsNothing);
  });

  testWidgets('starts collapsed with its count; expanded, muted rows say '
      'when they ended and open on tap', (tester) async {
    final opened = await _pump(tester, _tracks);
    expect(find.text('Ended sub-tracks (2)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('endedSubTrackRow:$_school')),
      findsNothing,
    );

    await tester.tap(find.text('Ended sub-tracks (2)'));
    await tester.pumpAndSettle();
    expect(find.text('School 2025–26'), findsOneWidget);
    expect(find.text('Ended Jul 2026'), findsOneWidget, reason: 'window_end');
    expect(find.text('Ended Sep 2026'), findsOneWidget, reason: 'ended_at');
    expect(find.bySemanticsLabel('Shiur, ended'), findsOneWidget);
    expect(find.textContaining('Completed'), findsNothing);
    expect(find.textContaining('complete'), findsNothing);

    final title = tester.widget<Text>(find.text('Shiur'));
    final header = tester.widget<Text>(find.text('Ended sub-tracks (2)'));
    expect(title.style?.color, header.style?.color, reason: 'muted ink');

    await tester.tap(find.byKey(const ValueKey('endedSubTrackRow:$_shiur')));
    expect(opened, [_shiur]);
  });
}
