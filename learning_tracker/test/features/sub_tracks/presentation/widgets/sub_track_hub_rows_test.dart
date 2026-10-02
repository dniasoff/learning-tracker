// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/sub_track_hub_rows.dart`
// (DNI-497 AC-1, AC-8): on the production Manage tracks hub
// (TrackManagementBody, no stand-in list) a sub-track row opens the
// detail route on a phone, and from 840dp selects in place with the
// detail beside the hub.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_list_detail_layout.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
  });

  late DetailHarness h;
  late _MockStackRouter router;
  final school = detailSubTrack(10, 'School', const [berakhot, peah]);
  final rebbe = detailSubTrack(20, 'Rebbe', const [shabbat]);
  final ended = detailSubTrack(30, 'Last year', const [shabbat], ended: true);
  final track = CurriculumTrackEntity(
    curriculumId: CurriculumId.mishnayos,
    state: 'active',
    stateChangedAt: DateTime.utc(2026),
    activatedAt: DateTime.utc(2026),
  );

  setUp(() {
    h = DetailHarness()..seed(subTracks: [school, rebbe, ended]);
    router = _MockStackRouter();
    when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  });
  tearDown(() => h.dispose());

  Future<void> pumpHub(WidgetTester tester, {required double width}) async {
    tester.view
      ..physicalSize = Size(width, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      pumpApp(
        retry: (_, _) => null,
        overrides: [
          ...h.overrides(),
          activeProfileIdProvider.overrideWithValue(
            '01J6Q2H4A8M7K3P9R5T6V8WXY8',
          ),
          activeTracksProvider.overrideWith((ref) => Stream.value([track])),
          dashboardHasProgramEnrollmentProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => false),
          trackHasChazaraProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => false),
          useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
        ],
        child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const TrackManagementBody(showBackButton: true),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  Finder row(String id) => find.byKey(ValueKey('subTrackHubRow:$id'));

  bool isSelected(WidgetTester tester, String id) =>
      tester.widget<ListTile>(row(id)).selected;

  testWidgets('the hub lists the non-ended sub-tracks; on a phone a row tap '
      'pushes the sub-track detail route', (tester) async {
    await pumpHub(tester, width: 400);
    expect(find.text('Sub-tracks'), findsOneWidget);
    expect(row(school.id), findsOneWidget);
    expect(row(rebbe.id), findsOneWidget);
    expect(row(ended.id), findsNothing, reason: 'ended is not a hub row');

    await tester.ensureVisible(row(rebbe.id));
    await tester.tap(row(rebbe.id));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final pushed = verify(() => router.push<Object?>(captureAny())).captured;
    expect(
      pushed.single,
      isA<SubTrackDetailRoute>().having(
        (r) => r.args?.subTrackId,
        'subTrackId',
        rebbe.id,
      ),
    );
    expect(find.byType(SubTrackDetailView), findsNothing);
  });

  testWidgets('from 840dp a row tap selects it and shows its detail beside '
      'the hub; the next tap updates the pane in place', (tester) async {
    await pumpHub(tester, width: 1100);
    expect(find.byType(SubTrackDetailView), findsNothing);

    await tester.tap(row(school.id));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final pane = find.byKey(const ValueKey('subTrackSplitDetail'));
    expect(pane, findsOneWidget);
    expect(
      tester.getTopLeft(pane).dx,
      greaterThanOrEqualTo(subTrackSplitListWidth),
    );
    expect(
      find.descendant(of: pane, matching: find.text('School')),
      findsOneWidget,
    );
    expect(isSelected(tester, school.id), isTrue);

    await tester.tap(row(rebbe.id));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(pane, findsOneWidget);
    expect(
      find.descendant(of: pane, matching: find.text('Rebbe')),
      findsOneWidget,
    );
    expect(isSelected(tester, rebbe.id), isTrue);
    expect(isSelected(tester, school.id), isFalse);
    verifyNever(() => router.push<Object?>(any()));
  });
}
