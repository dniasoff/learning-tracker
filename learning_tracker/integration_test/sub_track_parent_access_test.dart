// DNI-495 (story 2.4) AC-3 — with no parent-PIN session, no sub-track
// form, create command or hub entry point is reachable: not by a direct
// route, not by a deep link and not from Settings → Manage tracks. A parent
// session reaches both.
//
// Drives the REAL AppRouter route table and the real ParentSessionGuard
// (every other guard is permissive, so only the AC-3 gate decides) over the
// C0 in-memory ports. No emulator is needed:
//   flutter test integration_test/sub_track_parent_access_test.dart -d <device>
// The same flows run headless in test/features/sub_tracks/presentation/.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';

import '../test/helpers/pump_app.dart';
import '../test/helpers/sub_tracks/sub_track_harness.dart';
import '../test/helpers/sub_tracks/sub_track_router.dart';

const _formPath = '/settings/tracks/mishnayos/sub-tracks/school-year';

Future<void> _pumpAt(
  WidgetTester tester,
  SubTrackHarness h,
  String path, {
  required bool parentSession,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1600);
  addTearDown(tester.view.reset);
  final router = subTrackTestRouter(isParentSession: () => parentSession);
  await tester.pumpWidget(
    pumpApp(
      routerConfig: router.config(deepLinkBuilder: (_) => DeepLink.path(path)),
      overrides: [
        ...h.overrides(parentSession: parentSession),
        ...subTrackHubCardOverrides(),
      ],
      retry: (_, _) => null,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SubTrackHarness h;
  setUp(
    () => h = SubTrackHarness(
      seed: [storedSchoolYear('01JHARN0000000000000000001')],
    ),
  );
  tearDown(() async => h.dispose());

  test('the form route is behind the parent-session guard', () {
    final router = subTrackTestRouter(isParentSession: () => false);
    final route = router.routes.firstWhere(
      (r) => r.name == SchoolYearSubTrackFormRoute.name,
    );
    expect(route.path, '/settings/tracks/:curriculumId/sub-tracks/school-year');
    expect(route.guards.whereType<ParentSessionGuard>(), hasLength(1));
  });

  testWidgets('a child deep link to the form exposes nothing', (tester) async {
    await _pumpAt(tester, h, _formPath, parentSession: false);
    expect(find.byType(SchoolYearSubTrackFormScreen), findsNothing);
    expect(find.text('Save sub-track'), findsNothing);
    expect(h.commands.creates, isEmpty);
  });

  testWidgets('a child on Manage tracks sees no sub-track entry point', (
    tester,
  ) async {
    await _pumpAt(tester, h, '/settings/tracks', parentSession: false);
    expect(find.byType(TrackManagementBody), findsOneWidget);
    expect(find.byType(LearningTrackCard), findsOneWidget);
    expect(find.byType(SubTrackHubRow), findsNothing);
    expect(find.text('Add sub-track'), findsNothing);
  });

  testWidgets('a parent reaches the hub group and the form', (tester) async {
    await _pumpAt(tester, h, '/settings/tracks', parentSession: true);
    expect(find.text('Sub-tracks · 1 active'), findsOneWidget);
    await tester.tap(find.text('Add sub-track'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('School year'));
    await tester.pumpAndSettle();
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
  });

  testWidgets('a parent deep link opens the form directly', (tester) async {
    await _pumpAt(tester, h, _formPath, parentSession: true);
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
  });
}
