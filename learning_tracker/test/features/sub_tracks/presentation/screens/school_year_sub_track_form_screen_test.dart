/// Route-level states of [SchoolYearSubTrackFormScreen] (DNI-495); the AC
/// flows live in `../school_year_sub_track_form_test.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

void main() {
  late SubTrackHarness h;

  setUp(() => h = SubTrackHarness());
  tearDown(() async => h.dispose());

  testWidgets('a parent session sees the create form', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
  });

  testWidgets('a non-parent session renders no form (AC-3)', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(parentSession: false),
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });

  testWidgets('shows progress while the session resolves', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...h.overrides(parentSession: null),
          subTrackParentSessionProvider.overrideWith((ref) => pending.future),
        ],
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
  });

  testWidgets('an unknown sub-track id shows the error view', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
          subTrackId: '01JHARN0000000000000000099',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });

  testWidgets('a curriculum with no main track shows the error view, '
      'never the form', (tester) async {
    // A deep link naming an arbitrary curriculum id.
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(curriculumId: 'not_a_track'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });

  testWidgets('undecodable sub-track rows block the form (fail closed)', (
    tester,
  ) async {
    h.repo.seedRejected(h.scope, const [
      RejectedRow('01JHARN0000000000000000098', 'bad window_end'),
    ]);
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });
}
