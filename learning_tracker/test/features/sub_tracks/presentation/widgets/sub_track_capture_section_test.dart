// Story 2.10 (DNI-501) T3: the Learn-tab sub-track section (DNI-500 seam):
// absent with no onHome sub-track, rows in hub order, errors kept local.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capture_section.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';
import '../../helpers/up_to_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<List<OnHomeSubTrack>> rows,
) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...learnerStateOverrides(scope: c0Scope()),
        ...upToLabelOverrides(),
        onHomeSubTracksProvider.overrideWith((ref) => rows),
      ],
      child: const Scaffold(
        body: SingleChildScrollView(child: SubTrackCaptureSection()),
      ),
    ),
  );
  await tester.pump();
}

OnHomeSubTrack _row(String id, String name) => OnHomeSubTrack(
  track: fixtureSubTrack(id, name),
  state: fixtureSubTrackState(id, path: const ['Mishnah Berakhot 1:1']),
);

void main() {
  testWidgets('absent with no onHome sub-track; nothing invites creation', (
    tester,
  ) async {
    await _pump(tester, const AsyncData([]));
    expect(find.byKey(const Key('subTrackSection')), findsNothing);
    expect(find.textContaining('Also learning'), findsNothing);
  });

  testWidgets('one row per onHome sub-track, in the given hub order', (
    tester,
  ) async {
    await _pump(
      tester,
      AsyncData([_row(rebbeId, 'Rebbe'), _row(schoolId, 'School')]),
    );
    expect(find.text('Also learning · 2 sub-tracks'), findsOneWidget);
    final rebbe = tester.getTopLeft(find.text('Rebbe')).dy;
    final school = tester.getTopLeft(find.text('School')).dy;
    expect(rebbe, lessThan(school));
  });

  testWidgets('a load error stays inside the section with retry', (
    tester,
  ) async {
    await _pump(tester, AsyncError(StateError('x'), StackTrace.empty));
    expect(find.byKey(const Key('subTrackSectionError')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
