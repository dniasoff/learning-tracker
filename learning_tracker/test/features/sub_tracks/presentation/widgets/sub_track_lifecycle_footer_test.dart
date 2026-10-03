// Mirror test for `lib/features/sub_tracks/presentation/widgets/
// sub_track_lifecycle_footer.dart` (Story 2.8 / DNI-499, AC-1): the
// production *Add next year* opener pushes DNI-495's school-year form in
// its next-year mode, and that mode only rolls over a live school year of
// the route's curriculum.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_footer.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

class _Router extends Mock implements StackRouter {}

const _source = '01JHARN0000000000000000001';

void main() {
  late SubTrackHarness h;

  setUpAll(() => registerFallbackValue(const SettingsRoute()));
  tearDown(() async => h.dispose());

  testWidgets('Add next year pushes the school-year form for the source, '
      'by id, in next-year mode', (tester) async {
    h = SubTrackHarness(seed: [storedSchoolYear(_source)]);
    final router = _Router();
    when(() => router.push<bool>(any())).thenAnswer((_) async => true);
    final source = storedSchoolYear(_source);
    bool? saved;
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  saved = await openNextYearSubTrackForm(context, source),
              child: const Text('roll over'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('roll over'));
    await tester.pumpAndSettle();

    final pushed =
        verify(() => router.push<bool>(captureAny())).captured.single
            as SchoolYearSubTrackFormRoute;
    expect(pushed.args!.curriculumId, subTrackTestCurriculum);
    expect(pushed.args!.nextYearOf, _source);
    expect(pushed.args!.subTrackId, isNull, reason: 'never edits the source');
    expect(saved, isTrue);
  });

  for (final (label, seed) in [
    ('a tombstoned source', storedSchoolYear(_source, ended: true)),
    ('an ongoing source', storedOngoing(_source)),
    (
      "another curriculum's source",
      storedSchoolYear(_source, curriculumId: 'shas'),
    ),
    ('a missing source', null),
  ]) {
    testWidgets('the next-year form refuses $label (stale or crafted link)', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [?seed]);
      await tester.pumpWidget(
        pumpApp(
          overrides: h.overrides(),
          retry: (_, _) => null,
          child: const SchoolYearSubTrackFormScreen(
            curriculumId: subTrackTestCurriculum,
            nextYearOf: _source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(SchoolYearSubTrackForm), findsNothing);
    });
  }

  testWidgets('an open-ended school year rolls over open-ended', (
    tester,
  ) async {
    h = SubTrackHarness(seed: [storedSchoolYear(_source, openEnd: true)]);
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        retry: (_, _) => null,
        child: const SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
          nextYearOf: _source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
    expect(find.text('Next school year'), findsOneWidget);
    expect(find.text('No end month'), findsOneWidget);
  });
}
