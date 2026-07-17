// L1 widget tests — PermissionPromptScreen
//
// Covers:
//   • Onboarding variant: title "Almost Done!", CTA "Start Learning".
//   • Settings variant: title "App Permissions", CTA "Done".
//   • Both permission cards render (Notifications + Location).
//   • "Skip for now" present in idle state; absent once both permissions resolved.
//   • Tapping "Allow" on the Notifications card calls
//     notificationServiceProvider.requestPermission().
//   • Granted path: granted icon shown; denied path: denied icon shown.
//   • Tapping "Allow" on the Location card calls
//     sacredLocationProvider.notifier.detect().
//   • Location granted shows granted icon; denied shows denied icon.
//   • Primary CTA ("Done"/"Start Learning") calls context.maybePop().
//   • "Skip for now" calls context.maybePop().
//   • Skip button hidden after both permissions are resolved.
//   • He-RTL smoke: screen renders without overflow under he locale.
//   • Hardcoded string audit.

@Tags(['onboarding', 'permission_prompt'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/permission_prompt_screen.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockNotificationGateway extends Mock implements NotificationGateway {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Fake SacredLocationNotifier ───────────────────────────────────────────────
//
// We cannot easily mock the *notifier* because sacredLocationProvider is a
// $NotifierProvider and overrideWith() requires providing a real notifier
// instance. Instead we use a minimal subclass that delegates detect() to an
// injected closure, avoiding real geolocator calls.

// ── Hebrew Terms / nusach overrides ─────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

/// Fixed-nusach notifier so the Shabbos transliteration is deterministic.
class _FixedVariant extends CurrentTransliterationVariant {
  _FixedVariant(this._variant);

  final TransliterationVariant _variant;

  @override
  TransliterationVariant build() => _variant;
}

class _FakeSacredLocationNotifier extends SacredLocationNotifier {
  _FakeSacredLocationNotifier(this._detectResult);

  final Future<LocationFetchResult> Function() _detectResult;

  @override
  SacredLocation? build() => null; // no SharedPreferences in tests

  @override
  Future<LocationFetchResult> detect() => _detectResult();
}

// ── Build helper ──────────────────────────────────────────────────────────────

Widget _buildApp({
  required _MockNotificationGateway notifGateway,
  required _MockStackRouter router,
  required _FakeSacredLocationNotifier locationNotifier,
  bool isOnboarding = false,
  Locale locale = const Locale('en'),
  bool useHebrewTerms = false,
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
}) {
  return pumpApp(
    locale: locale,
    overrides: [
      notificationServiceProvider.overrideWithValue(notifGateway),
      sacredLocationProvider.overrideWith(() => locationNotifier),
      useHebrewTermsProvider.overrideWith(
        () => useHebrewTerms ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
      ),
      currentTransliterationVariantProvider.overrideWith(
        () => _FixedVariant(variant),
      ),
    ],
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: PermissionPromptScreen(isOnboarding: isOnboarding),
    ),
  );
}

// ── Pump helpers ──────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Default mocks ─────────────────────────────────────────────────────────────

_MockStackRouter _defaultRouter() {
  final router = _MockStackRouter();
  when(() => router.canPop()).thenReturn(true);
  // The auto_route extension calls router.maybePop<Object?>(null).
  // Stub with the concrete null argument since any<Object?>() does not
  // match null in mocktail.
  when(() => router.maybePop<Object?>(null)).thenAnswer((_) async => true);
  return router;
}

_MockNotificationGateway _defaultNotifGateway({bool granted = true}) {
  final gw = _MockNotificationGateway();
  when(() => gw.requestPermission()).thenAnswer((_) async => granted);
  return gw;
}

_FakeSacredLocationNotifier _locationNotifier(LocationFetchResult result) {
  return _FakeSacredLocationNotifier(() async => result);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  // ── Onboarding variant ──────────────────────────────────────────────────────

  group('PermissionPromptScreen — onboarding variant', () {
    testWidgets('title is "Almost Done!" when isOnboarding=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          isOnboarding: true,
        ),
      );
      await _pump(tester);

      expect(find.text('Almost Done!'), findsOneWidget);
      expect(find.text('App Permissions'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('CTA reads "Start Learning" when isOnboarding=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          isOnboarding: true,
        ),
      );
      await _pump(tester);

      expect(find.text('Start Learning'), findsOneWidget);
      expect(find.text('Done'), findsNothing);

      await _teardown(tester);
    });
  });

  // ── Settings variant ────────────────────────────────────────────────────────

  group('PermissionPromptScreen — settings variant', () {
    testWidgets('title is "App Permissions" when isOnboarding=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      expect(find.text('App Permissions'), findsOneWidget);
      expect(find.text('Almost Done!'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('CTA reads "Done" when isOnboarding=false', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Start Learning'), findsNothing);

      await _teardown(tester);
    });
  });

  // ── Initial render ──────────────────────────────────────────────────────────

  group('PermissionPromptScreen — initial render', () {
    testWidgets('both permission cards are shown', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('both "Allow" buttons present in idle state', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      expect(find.text('Allow'), findsNWidgets(2));

      await _teardown(tester);
    });

    testWidgets('"Skip for now" button present in idle state', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      expect(find.text('Skip for now'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('notification and location icons are present', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── Notification permission ─────────────────────────────────────────────────

  group('PermissionPromptScreen — notification permission', () {
    testWidgets(
      'tapping Allow on Notifications calls gateway.requestPermission()',
      (tester) async {
        final notifGateway = _defaultNotifGateway(granted: true);
        await tester.pumpWidget(
          _buildApp(
            notifGateway: notifGateway,
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
          ),
        );
        await _pump(tester);

        // The first "Allow" FilledButton is the Notifications card.
        await tester.tap(find.text('Allow').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(() => notifGateway.requestPermission()).called(1);

        await _teardown(tester);
      },
    );

    testWidgets(
      'granted: check_circle icon shown for notification card after grant',
      (tester) async {
        final notifGateway = _defaultNotifGateway(granted: true);
        await tester.pumpWidget(
          _buildApp(
            notifGateway: notifGateway,
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Allow').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets('denied: cancel icon shown for notification card after deny', (
      tester,
    ) async {
      final notifGateway = _defaultNotifGateway(granted: false);
      await tester.pumpWidget(
        _buildApp(
          notifGateway: notifGateway,
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Allow').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('notification Allow button disabled after resolution', (
      tester,
    ) async {
      final notifGateway = _defaultNotifGateway(granted: true);
      await tester.pumpWidget(
        _buildApp(
          notifGateway: notifGateway,
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Allow').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Only 1 "Allow" button left (Location card still idle)
      expect(find.text('Allow'), findsOneWidget);

      // Second tap on notification gateway must NOT fire again
      await tester.tap(find.text('Allow'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Still called only once
      verify(() => notifGateway.requestPermission()).called(1);

      await _teardown(tester);
    });
  });

  // ── Location permission ─────────────────────────────────────────────────────

  group('PermissionPromptScreen — location permission', () {
    testWidgets(
      'tapping Allow on Location card calls sacredLocationProvider.notifier.detect()',
      (tester) async {
        var detectCalled = false;
        final locationNotif = _FakeSacredLocationNotifier(() async {
          detectCalled = true;
          return const LocationFetchPermissionDenied(permanentlyDenied: false);
        });

        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: locationNotif,
          ),
        );
        await _pump(tester);

        // Tap the second "Allow" button (Location card)
        await tester.tap(find.text('Allow').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(detectCalled, isTrue, reason: 'detect() must have been called');

        await _teardown(tester);
      },
    );

    testWidgets(
      'LocationFetchSuccess: check_circle icon shown for location card',
      (tester) async {
        final locationNotif = _locationNotifier(
          LocationFetchSuccess(
            SacredLocation(
              latitude: 31.7,
              longitude: 35.2,
              source: SacredLocationSource.detected,
              fixedAt: DateTime.utc(2026),
            ),
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: locationNotif,
          ),
        );
        await _pump(tester);

        // Tap Location Allow
        await tester.tap(find.text('Allow').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets(
      'LocationFetchPermissionDenied: cancel icon shown for location card',
      (tester) async {
        final locationNotif = _locationNotifier(
          const LocationFetchPermissionDenied(permanentlyDenied: false),
        );

        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: locationNotif,
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Allow').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets(
      'LocationFetchServiceDisabled: cancel icon shown for location card',
      (tester) async {
        final locationNotif = _locationNotifier(
          const LocationFetchServiceDisabled(),
        );

        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: locationNotif,
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Allow').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets('LocationFetchError: cancel icon shown for location card', (
      tester,
    ) async {
      final locationNotif = _locationNotifier(
        const LocationFetchError(LocationErrorCode.timeout),
      );

      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: locationNotif,
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Allow').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── Skip / CTA navigation ───────────────────────────────────────────────────

  group('PermissionPromptScreen — navigation', () {
    testWidgets('"Skip for now" calls context.maybePop()', (tester) async {
      final router = _defaultRouter();
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: router,
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Skip for now'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => router.maybePop<Object?>(null),
      ).called(greaterThanOrEqualTo(1));

      await _teardown(tester);
    });

    testWidgets(
      'primary CTA ("Done") calls context.maybePop() from settings mode',
      (tester) async {
        final router = _defaultRouter();
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: router,
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(
          () => router.maybePop<Object?>(null),
        ).called(greaterThanOrEqualTo(1));

        await _teardown(tester);
      },
    );

    testWidgets(
      'primary CTA ("Start Learning") calls context.maybePop() in onboarding mode',
      (tester) async {
        final router = _defaultRouter();
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: router,
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            isOnboarding: true,
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Start Learning'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(
          () => router.maybePop<Object?>(null),
        ).called(greaterThanOrEqualTo(1));

        await _teardown(tester);
      },
    );
  });

  // ── Skip button hidden once both resolved ────────────────────────────────────

  group('PermissionPromptScreen — skip button visibility', () {
    testWidgets(
      '"Skip for now" hidden once both notifications and location are resolved',
      (tester) async {
        final notifGateway = _defaultNotifGateway(granted: true);
        final locationNotif = _locationNotifier(
          const LocationFetchPermissionDenied(permanentlyDenied: false),
        );

        await tester.pumpWidget(
          _buildApp(
            notifGateway: notifGateway,
            router: _defaultRouter(),
            locationNotifier: locationNotif,
          ),
        );
        await _pump(tester);

        // Resolve notifications
        await tester.tap(find.text('Allow').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Skip still visible (location still idle)
        expect(find.text('Skip for now'), findsOneWidget);

        // Resolve location
        await tester.tap(find.text('Allow'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Skip now hidden
        expect(find.text('Skip for now'), findsNothing);

        await _teardown(tester);
      },
    );
  });

  // ── He-RTL smoke ─────────────────────────────────────────────────────────────

  group('PermissionPromptScreen — he-RTL smoke', () {
    testWidgets('renders without overflow under Hebrew locale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No overflow assertions: if this pump completes without throwing,
      // the RTL layout is not broken.
      expect(find.byType(Scaffold), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('he locale: AppBar renders without overflow', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          locale: const Locale('he'),
        ),
      );
      await _pump(tester);

      expect(find.byType(AppBar), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── Shabbos domain term (toggle + nusach aware) ──────────────────────────────

  group('PermissionPromptScreen — Shabbos domain term', () {
    testWidgets('Ashkenazi nusach renders "Shabbos" in the body + card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          isOnboarding: true,
        ),
      );
      await _pump(tester);

      expect(find.textContaining('Shabbos'), findsWidgets);
      expect(find.textContaining('Shabbat'), findsNothing);
      expect(find.textContaining('שבת'), findsNothing);
      // Havdalah term resolves to the Ashkenazi spelling in the location card.
      expect(find.textContaining('Havdalah'), findsWidgets);
      expect(find.textContaining('הבדלה'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('Sephardi nusach renders "Shabbat" and "Havdala"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          isOnboarding: true,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await _pump(tester);

      expect(find.textContaining('Shabbat'), findsWidgets);
      expect(find.textContaining('Shabbos'), findsNothing);
      // Sephardi Havdalah spelling drops the trailing "h" → "Havdala".
      expect(find.textContaining('Havdala'), findsWidgets);
      expect(find.textContaining('Havdalah'), findsNothing);

      await _teardown(tester);
    });

    testWidgets(
      'Hebrew Terms ON renders "שבת" + "הבדלה" (nusach-independent)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            isOnboarding: true,
            useHebrewTerms: true,
          ),
        );
        await _pump(tester);

        expect(find.textContaining('שבת'), findsWidgets);
        expect(find.textContaining('Shabbos'), findsNothing);
        expect(find.textContaining('Shabbat'), findsNothing);
        // Havdalah term resolves to Hebrew script when the toggle is on.
        expect(find.textContaining('הבדלה'), findsWidgets);
        expect(find.textContaining('Havdalah'), findsNothing);
        expect(find.textContaining('Havdala'), findsNothing);

        await _teardown(tester);
      },
    );
  });

  // ── Hardcoded string audit / Hebrew l10n assertion ───────────────────────────
  //
  // RED→GREEN: Previously the screen used hardcoded English literals; now it
  // must render the correct l10n values for every locale.

  group('PermissionPromptScreen — Hebrew l10n (rationale copy)', () {
    testWidgets(
      'he locale: AppBar shows "כמעט סיימנו!" (not "Almost Done!") in onboarding',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            isOnboarding: true,
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        expect(find.text('כמעט סיימנו!'), findsOneWidget);
        expect(find.text('Almost Done!'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets(
      'he locale: notifications card title shows "התראות" (not "Notifications")',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        expect(find.text('התראות'), findsOneWidget);
        expect(find.text('Notifications'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets(
      'he locale: location card title shows "מיקום" (not "Location")',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        expect(find.text('מיקום'), findsOneWidget);
        expect(find.text('Location'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets('he locale: Allow button shows "אפשר" (not "Allow")', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          notifGateway: _defaultNotifGateway(),
          router: _defaultRouter(),
          locationNotifier: _locationNotifier(
            const LocationFetchPermissionDenied(permanentlyDenied: false),
          ),
          locale: const Locale('he'),
        ),
      );
      await _pump(tester);

      expect(find.text('אפשר'), findsNWidgets(2));
      expect(find.text('Allow'), findsNothing);

      await _teardown(tester);
    });

    testWidgets(
      'he locale: primary CTA shows "סיום" (not "Done") in settings mode',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        expect(find.text('סיום'), findsOneWidget);
        expect(find.text('Done'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets(
      'he locale: notif subtitle shows Hebrew rationale (not English)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notifGateway: _defaultNotifGateway(),
            router: _defaultRouter(),
            locationNotifier: _locationNotifier(
              const LocationFetchPermissionDenied(permanentlyDenied: false),
            ),
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        expect(
          find.text('תזכורות לימוד יומיות והתראות להגנת הרצף.'),
          findsOneWidget,
        );
        expect(
          find.text('Daily learning reminders and streak-protection alerts.'),
          findsNothing,
        );

        await _teardown(tester);
      },
    );
  });
}
