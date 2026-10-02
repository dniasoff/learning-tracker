// Story 2.9 (DNI-500) AC-1, AC-6 — the section's own states: absent,
// header + rows, and a local error with retry.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/also_learning_section.dart';

import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<List<SubTrackHomeItem>> Function() items,
) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...learnerStateOverrides(scope: null),
        homeSubTracksProvider.overrideWith((ref) => items()),
        subTrackViewerRoleProvider.overrideWithValue(SubTrackViewerRole.child),
        ...positionLabelOverrides(),
      ],
      child: const Scaffold(
        body: SingleChildScrollView(child: AlsoLearningSection(topSpacing: 24)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _school = SubTrackHomeItem(
  subTrackId: schoolId,
  curriculumId: mishnayos,
  name: 'School',
  kind: SubTrackRowKind.active,
  position: berachos14,
);

const _rebbe = SubTrackHomeItem(
  subTrackId: rebbeId,
  curriculumId: mishnayos,
  name: 'Rebbe',
  kind: SubTrackRowKind.active,
  position: peah21,
);

void main() {
  testWidgets('no onHome sub-track: the section is absent, nothing invites '
      'creating one', (tester) async {
    await _pump(tester, () => const AsyncData([]));
    expect(find.byKey(const Key('alsoLearningSection')), findsNothing);
    expect(find.textContaining('Also learning'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.getSize(find.byType(AlsoLearningSection)).height, 0);
  });

  testWidgets('loading stays local and takes no space', (tester) async {
    await _pump(tester, () => const AsyncLoading());
    expect(tester.getSize(find.byType(AlsoLearningSection)).height, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('header counts the rows; one row per item in order', (
    tester,
  ) async {
    await _pump(tester, () => const AsyncData([_school, _rebbe]));
    expect(find.text('Also learning · 2 sub-tracks'), findsOneWidget);
    final school = tester.getTopLeft(find.text('School'));
    final rebbe = tester.getTopLeft(find.text('Rebbe'));
    expect(school.dy, lessThan(rebbe.dy));
  });

  testWidgets('singular header', (tester) async {
    await _pump(tester, () => const AsyncData([_school]));
    expect(find.text('Also learning · 1 sub-track'), findsOneWidget);
  });

  testWidgets('a load error shows InlineAsyncError with retry', (tester) async {
    var builds = 0;
    await _pump(tester, () {
      builds++;
      return AsyncError(StateError('down'), StackTrace.empty);
    });
    expect(find.byType(InlineAsyncError), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final before = builds;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(InlineAsyncError), findsOneWidget);
    expect(builds, greaterThanOrEqualTo(before));
  });
}
