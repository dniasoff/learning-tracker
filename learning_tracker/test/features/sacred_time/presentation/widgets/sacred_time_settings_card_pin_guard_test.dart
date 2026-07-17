/// AUD-sacred_time-08 regression test: SacredTimeSettingsCard must gate its
/// escalating location actions (Detect / Choose City) behind a Parent PIN
/// challenge when `pinGuardRequired` is true — mirroring
/// ProfileSwitcherSheet's AN-2 `_guardEscalating` pattern
/// (`an2_switcher_pin_guard_test.dart`).
///
/// Why this card needs its own gate: DEC-26 made Sacred Time / location a
/// DEVICE-scoped setting, so the card renders in Settings' DEVICE section for
/// every profile — including children — and `SettingsRoute` itself carries no
/// route-level PIN/child-mode guard (app_router.dart: `/` → `settings` has
/// only `authGuard`, unlike the PIN-guarded `/parent-mode/*` routes). Without
/// an in-card gate, a child on a shared device could trigger GPS detection or
/// pick a new city with no parent authentication.
///
/// RED -> GREEN cycle:
///   RED:  tapping Detect/Choose City while pinGuardRequired=true fires the
///         action directly — no PIN dialog shown.
///   GREEN: the same taps show the Parent PIN verification dialog first, and
///          the underlying action does not run until it succeeds.
@Tags(['sacred_time', 'settings_card', 'pin_guard', 'regression'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// Skips real SharedPreferences/GPS I/O — the guard is what's under test,
/// not the detect flow itself.
class _FakeSacredLocationNotifier extends SacredLocationNotifier {
  @override
  SacredLocation? build() => null;

  @override
  Future<LocationFetchResult> detect() async =>
      const LocationFetchServiceDisabled();
}

class _FakeInIsraelNotifier extends InIsraelNotifier {
  @override
  bool build() => false;
}

Widget _buildCard({required bool pinGuardRequired, StackRouter? router}) {
  final mockRouter = router ?? _MockStackRouter();
  return pumpApp(
    overrides: [
      sacredLocationProvider.overrideWith(_FakeSacredLocationNotifier.new),
      inIsraelProvider.overrideWith(_FakeInIsraelNotifier.new),
      syncWriteFacadeProvider.overrideWithValue(null),
    ],
    child: StackRouterScope(
      controller: mockRouter,
      stateHash: 0,
      child: Scaffold(
        body: SacredTimeSettingsCard(
          pinGuardRequired: pinGuardRequired,
          activeProfileId: 2,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AUD-sacred_time-08 PIN guard for Sacred Time location actions', () {
    testWidgets('Detect shows Parent PIN dialog when pinGuardRequired=true', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(pinGuardRequired: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Detect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Enter Parent PIN'),
        findsOneWidget,
        reason:
            'AUD-sacred_time-08: tapping Detect while pinGuardRequired is '
            'true must show the Parent PIN verification dialog first.',
      );
    });

    testWidgets(
      'Choose city shows Parent PIN dialog when pinGuardRequired=true',
      (tester) async {
        await tester.pumpWidget(_buildCard(pinGuardRequired: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose city'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AUD-sacred_time-08: tapping Choose city while '
              'pinGuardRequired is true must show the Parent PIN '
              'verification dialog first, not navigate directly.',
        );
      },
    );

    testWidgets(
      'no PIN dialog and Detect proceeds when pinGuardRequired=false',
      (tester) async {
        await tester.pumpWidget(_buildCard(pinGuardRequired: false));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Detect'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Enter Parent PIN'),
          findsNothing,
          reason:
              'AUD-sacred_time-08: when the guard is not required, Detect '
              'must fire immediately with no PIN prompt.',
        );
        // The fake notifier's detect() resolves to ServiceDisabled — its
        // SnackBar confirms the action actually ran, not just that no dialog
        // appeared.
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'no PIN dialog and Choose city navigates when pinGuardRequired=false',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(
          () => mockRouter.push<Object?>(any()),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          _buildCard(pinGuardRequired: false, router: mockRouter),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose city'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Enter Parent PIN'), findsNothing);
        verify(() => mockRouter.push<Object?>(any())).called(1);
      },
    );
  });
}
