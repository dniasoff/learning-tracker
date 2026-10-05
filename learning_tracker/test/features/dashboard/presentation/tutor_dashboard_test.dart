// Story 4.2 (DNI-510) AC-7 — a tutor viewing his talmid's Dashboard sees
// the on-track card, projection, daily target and shortfall warning the
// parent sees (UX-DR-48, UX-DR-97); he does not get Change history or Undo
// (parent-only: DNI-513's route refuses a tutored session). A talmid's
// configured Sacred-Time lock does not cover the tutor's device.

@Tags(['tutor_mode'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/own_session_guard.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/learner_today_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/shortfall_warning_card.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../helpers/learner_state/lock_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/tutoring/tutor_learning_harness.dart';

class _MockResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

final _state = forecastState([
  forecastCurriculumState(
    projection: const Projection(
      status: ProjectionStatus.behindPace,
      velocityPerDay: 1.5,
      projectedFinish: '2029-03-14',
      deadline: '2028-09-01',
      newlyLearntToday: 3,
    ),
    dailyTarget: 4,
    subTracks: {
      schoolSubTrackId: shortfallSubTrack(
        id: schoolSubTrackId,
        name: 'School',
        shortfall: 40,
        lastNode: const NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 3'),
        windowEnd: '2027-07-31',
      ),
    },
  ),
]);

Widget _shortfalls(CurriculumForecast forecast) =>
    ShortfallWarningList(forecast: forecast);

Finder _text(String text) => find.textContaining(text, findRichText: true);

void main() {
  testWidgets('the tutor sees the parent forecast: on-track status, '
      'projection, daily target and the shortfall warning', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        theme: AppTheme.lightTheme(),
        overrides: [
          // Not a parent session: the tutor's access is his tutor mode.
          ...forecastOverrides(parent: false, state: _state),
          activeTutoredProfileSelectionProvider.overrideWith(
            () => FixedTutoredSelection(tutorSelection()),
          ),
        ],
        child: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                // As the Dashboard mounts it (dashboard_body.dart).
                ParentForecastSection(belowCard: _shortfalls),
                NonParentTodaySection(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_text('Behind pace'), findsOneWidget);
    expect(_text('Projected finish: Mar 14, 2029'), findsOneWidget);
    expect(_text('Daily target: 4'), findsOneWidget);
    expect(_text('School'), findsWidgets, reason: 'the shortfall warning');
    expect(
      find.byType(LearnerTodaySection),
      findsNothing,
      reason: 'the tutor gets the parent forecast, not the child view',
    );
  });

  test('Change history (and its Undo) stays parent-only: the route refuses '
      'a tutored session', () async {
    final resolver = _MockResolver();
    bool? allowed;
    when(() => resolver.isResolved).thenReturn(false);
    when(() => resolver.next(any())).thenAnswer((i) {
      allowed = i.positionalArguments.first as bool;
    });
    await OwnSessionGuard(
      isTutoredSession: () => true,
    ).onNavigation(resolver, _MockStackRouter());
    expect(allowed, isFalse);
  });

  testWidgets(
    "the talmid's configured lock does not cover the tutor's device",
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        pumpApp(
          overrides: tutoredOverrides(
            selection: tutorSelection(),
            lockSettings: constantHistory(newYorkLocated),
            deviceLockHistories: [constantHistory(newYorkNoLocation)],
            pinDeviceWindow: false,
            deviceNow: DateTime.utc(2026, 9, 5, 19),
          ),
          child: SacredTimeLockOverlay(
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('talmid dashboard'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('talmid dashboard'));
      expect(taps, 1, reason: 'the talmid lock does not cover the tutor');
      expect(find.text('talmid dashboard'), findsOneWidget);
    },
  );
}
