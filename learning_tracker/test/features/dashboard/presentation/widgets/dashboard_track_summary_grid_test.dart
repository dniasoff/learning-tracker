// Story 2.11 (DNI-502) AC-9: the tablet Dashboard's summary grid (#03).
//
// From the expanded width the main track and the sub-track summary cards
// sit side by side (7 and 5 of 12 columns); on a phone, or while there is
// no sub-track to show, they stack and the main track keeps the full width.
// Nothing overflows in either layout, in light or dark.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_sub_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_track_summary_grid.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/shortfall_warning_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/dashboard/epic2_surfaces.dart';
import '../../../../helpers/dashboard/forecast_fixtures.dart';

final _state = forecastState([
  forecastCurriculumState(
    projection: const Projection(
      status: ProjectionStatus.behindPace,
      projectedFinish: '2029-03-14',
      deadline: '2029-09-10',
    ),
    dailyTarget: 3,
    subTracks: {
      schoolSubTrackId: shortfallSubTrack(
        id: schoolSubTrackId,
        name: 'School',
        shortfall: 40,
        lastNode: const NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot 3'),
        windowEnd: '2027-07-31',
      ),
      rebbeSubTrackId: shortfallSubTrack(
        id: rebbeSubTrackId,
        name: 'Rebbe',
        shortfall: 0,
        lastNode: const NodeEntry(level: 'masechta', ref: 'Mishnah Beitzah'),
      ),
    },
  ),
]);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  bool withSubTracks = true,
  ThemeData? theme,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = Epic2MockRouter();
  when(() => router.isRouteActive(any())).thenReturn(false);
  await tester.pumpWidget(
    dashboardSurface(
      router: router,
      parent: true,
      mode: ProfileMode.adult,
      state: _state,
      theme: theme,
      extra: withSubTracks ? epic2SubTrackOverrides() : const [],
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _grid => find.byKey(const Key('dashboardTrackSummaryGrid'));

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('landscape tablet ($name): main track and sub-track cards '
        'side by side, 7 to 5, top aligned', (tester) async {
      await _pump(tester, size: const Size(1280, 3200), theme: theme());
      expect(tester.takeException(), isNull);

      // The status row and the full-width warning stay above the grid.
      expect(find.byType(OnTrackCard), findsOneWidget);
      expect(find.byType(ShortfallWarningCard), findsOneWidget);
      expect(_grid, findsOneWidget);

      final main = tester.getRect(find.byType(ActiveTracksCarouselSection));
      final cards = find.byType(DashboardSubTrackCard);
      expect(cards, findsNWidgets(2));
      final first = tester.getRect(cards.first);
      expect(first.left, greaterThan(main.right));
      expect(first.left - main.right, closeTo(kDashboardSummaryGridGap, 0.5));
      expect(main.width / first.width, closeTo(7 / 5, 0.01));
      final warning = tester.getRect(find.byType(ShortfallWarningCard));
      expect(warning.top, lessThan(main.top));
      expect(warning.width, greaterThan(main.width + first.width));
    });
  }

  testWidgets('phone: the sub-track cards stack under the main track', (
    tester,
  ) async {
    await _pump(tester, size: const Size(400, 3200));
    expect(tester.takeException(), isNull);
    expect(_grid, findsNothing);
    final main = tester.getRect(find.byType(ActiveTracksCarouselSection));
    final first = tester.getRect(find.byType(DashboardSubTrackCard).first);
    expect(first.top, greaterThan(main.bottom));
  });

  testWidgets('tablet with no on-home sub-track: the main track keeps the '
      'full width', (tester) async {
    await _pump(tester, size: const Size(1280, 3200), withSubTracks: false);
    expect(tester.takeException(), isNull);
    expect(_grid, findsNothing);
    expect(find.byType(DashboardSubTrackCard), findsNothing);
    final main = tester.getRect(find.byType(ActiveTracksCarouselSection));
    final warning = tester.getRect(find.byType(ShortfallWarningCard));
    expect(main.width, closeTo(warning.width, 1));
  });
}
