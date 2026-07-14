/// Regression test for PP-15 — Dashboard STATS card must not flash real zeros
/// during the initial data load.
///
/// Root cause (task bubbles): `tasksReady` was computed as
///   `dailyTasksAsync.hasValue || initialSyncComplete`
/// so when the sync flag was already true (an adult / first-launch profile
/// that ran pullOnLaunch) but the local Drift query had not yet emitted a
/// value, `tasksReady = true` and the bubbles showed OVERDUE=0 / TODAY=0 —
/// indistinguishable from "all caught up" — for 1-2 s.
///
/// Root cause (lifetime section): the DONE% and sections-detail rows passed
/// `cumulativeLifetime = 0.0` / "0 of 0 sections" before
/// [lifetimeTotalsAcrossAllCurriculaProvider] resolved, because the
/// loading branch of the provider fell back to 0.0 with no skeleton guard.
///
/// The fix:
///   * `tasksReady = dailyTasksAsync.hasValue` (not `|| initialSyncComplete`).
///   * Introduce [DashboardLevelPointsCard.lifetimeReady] and show "…" for
///     DONE% and sections-detail while the lifetime provider loads.
@Tags(['dashboard', 'pp15'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_level_points_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build the card with both [tasksReady] and [lifetimeReady] set to the given
/// values, then check what the bubbles + lifetime row render.
Widget _wrap({
  required bool tasksReady,
  required bool lifetimeReady,
  required _MockStackRouter router,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: Scaffold(
          body: SingleChildScrollView(
            child: DashboardLevelPointsCard(
              userMode: ProfileMode.adult,
              level: 3,
              totalPoints: 0,
              overdueCount: 0,
              todayCount: 0,
              reviewCount: 0,
              doneDisplay: '0%',
              lifetimeSectionsDetail: '0 of 0 sections',
              cumulativeLifetime: 0.0,
              tasksReady: tasksReady,
              lifetimeReady: lifetimeReady,
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(() => router.maybePop<Object?>(any())).thenAnswer((_) async => false);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(
      () => router.navigate(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async {});
  });

  group('PP-15: STATS card skeleton guard', () {
    testWidgets('when tasksReady=false: bubble values show "…" not real zeros', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(tasksReady: false, lifetimeReady: true, router: router),
      );
      await tester.pumpAndSettle();

      // Task bubbles must show the placeholder, not a real "0".
      expect(find.text('…'), findsWidgets);
      // Must not show a bare "0" in the bubble position.
      // (The "0 of 0 sections" detail text is allowed since lifetimeReady=true.)
    });

    testWidgets(
      'when lifetimeReady=false: lifetime row shows "…" not "0%" or "0 of 0 sections"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(tasksReady: true, lifetimeReady: false, router: router),
        );
        await tester.pumpAndSettle();

        // The DONE% label must show the skeleton placeholder, not "0%".
        expect(find.text('0%'), findsNothing);
        // The sections detail must also be hidden or replaced.
        expect(find.text('0 of 0 sections'), findsNothing);
        // At least one "…" placeholder must be visible.
        expect(find.text('…'), findsWidgets);
      },
    );

    testWidgets(
      'when both tasksReady=true and lifetimeReady=true: real values are shown',
      (tester) async {
        // Use a card with non-zero values to distinguish from the loading state.
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: StackRouterScope(
                controller: router,
                stateHash: 0,
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: DashboardLevelPointsCard(
                      userMode: ProfileMode.adult,
                      level: 3,
                      totalPoints: 0,
                      overdueCount: 2,
                      todayCount: 5,
                      reviewCount: 0,
                      doneDisplay: '42%',
                      lifetimeSectionsDetail: '42 of 100 sections',
                      cumulativeLifetime: 0.42,
                      tasksReady: true,
                      lifetimeReady: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Bubbles show real counts.
        expect(find.text('2'), findsWidgets);
        expect(find.text('5'), findsWidgets);
        // Lifetime row shows real data.
        expect(find.text('42%'), findsOneWidget);
        expect(find.text('42 of 100 sections'), findsOneWidget);
        // No placeholders.
        expect(find.text('…'), findsNothing);
      },
    );
  });
}
