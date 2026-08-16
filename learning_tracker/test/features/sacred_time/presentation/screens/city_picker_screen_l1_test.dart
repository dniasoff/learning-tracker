// L1 widget tests — CityPickerScreen
//
// Covers:
//   • Initial render: AppBar title + search field + idle hint when query < 2.
//   • Typing < 2 chars keeps idle hint visible (no provider call).
//   • Typing ≥ 2 chars shows loading state (CircularProgressIndicator) while
//     citySearchProvider is in AsyncLoading.
//   • Data state: matching cities render as ListTile rows (name + subtitle).
//   • Empty state: "No matches for …" shown when result list is empty.
//   • Error state: generic "Search failed…" shown when citySearchProvider
//     errors; the raw exception text never renders, in EN or he locale
//     (AUD-sacred_time-03, EH-5).
//   • Selecting a city calls sacredLocationProvider.notifier.setManualCity()
//     with the correct lat/lng/cityLabel/countryCode.
//   • Selecting a city triggers router.pop with the chosen City.
//   • Subtitle includes admin1 and countryCode separated by " · ".
//   • Subtitle omits admin1 when it is null/empty.
//   • He-RTL smoke: screen renders without overflow under he locale.
//   • No track-type label (Personal/Standard/Custom/אישי) anywhere.
//
// PUMP RIG:
//   ProviderScope(overrides:[...], child: MaterialApp(locale, delegates,
//   home: StackRouterScope(controller: router, child: CityPickerScreen())))
//   Double pump: await tester.pump(); await tester.pump(Duration(seconds:1)).
//   Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).
//
// retry: (_, __) => null is set at ProviderScope level so Riverpod 3 auto-
// retry doesn't keep errored FutureProviders in AsyncLoading forever.

@Tags(['sacred_time', 'city_picker', 'l1'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/cities_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/screens/city_picker_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Fake SacredLocationNotifier ────────────────────────────────────────────────
//
// Captures the setManualCity call arguments so tests can assert on them
// without triggering real SharedPreferences I/O or sync pushes.

class _FakeSacredLocationNotifier extends SacredLocationNotifier {
  SacredLocation? lastSet;

  @override
  SacredLocation? build() => null; // skip SharedPreferences load

  @override
  Future<void> setManualCity({
    required double latitude,
    required double longitude,
    required String cityLabel,
    required String countryCode,
  }) async {
    lastSet = SacredLocation(
      latitude: latitude,
      longitude: longitude,
      source: SacredLocationSource.manualCity,
      fixedAt: DateTime.utc(2026, 1, 1),
      countryCode: countryCode,
      cityLabel: cityLabel,
    );
    state = lastSet;
    // Do NOT call super — avoids SharedPreferences + sync side-effects.
  }
}

// ── Sample data ────────────────────────────────────────────────────────────────

const _cityJerusalem = City(
  id: 1,
  name: 'Jerusalem',
  countryCode: 'IL',
  latitude: 31.7683,
  longitude: 35.2137,
  population: 936425,
  admin1: 'Jerusalem District',
);

const _cityTelAviv = City(
  id: 2,
  name: 'Tel Aviv',
  countryCode: 'IL',
  latitude: 32.0853,
  longitude: 34.7818,
  population: 432892,
  admin1: 'Tel Aviv District',
);

const _cityNoAdmin = City(
  id: 3,
  name: 'Nomadville',
  countryCode: 'US',
  latitude: 40.0,
  longitude: -75.0,
  population: 1000,
  // admin1 intentionally null
);

// ── Build helper ───────────────────────────────────────────────────────────────

Widget _buildApp({
  required _MockStackRouter router,
  required _FakeSacredLocationNotifier locationNotifier,

  /// Override for citySearchProvider('<query>'). Key = query string.
  Map<String, Future<List<City>> Function(Ref)> citySearchOverrides = const {},
  Locale locale = const Locale('en'),
}) {
  final overrides = <Override>[
    sacredLocationProvider.overrideWith(() => locationNotifier),
    ...citySearchOverrides.entries.map(
      (e) => citySearchProvider(e.key).overrideWith(e.value),
    ),
  ];

  return ProviderScope(
    // Mandatory: disables Riverpod 3 auto-retry so error states are surfaced
    // immediately in tests (without this, errored FutureProviders stay in
    // AsyncLoading indefinitely).
    retry: (_, __) => null,
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const CityPickerScreen(),
      ),
    ),
  );
}

// ── Default mock router ────────────────────────────────────────────────────────

_MockStackRouter _defaultRouter() {
  final router = _MockStackRouter();
  when(() => router.canPop()).thenReturn(true);
  when(() => router.pop<City>(any<City>())).thenAnswer((_) async => true);
  return router;
}

// ── Pump helpers ───────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(_cityJerusalem);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Initial render ────────────────────────────────────────────────────────

  group('CityPickerScreen — initial render', () {
    testWidgets('AppBar title shows "Choose a city"', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
        ),
      );
      await _pump(tester);

      expect(find.text('Choose a city'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('search TextField with hint text is present', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
        ),
      );
      await _pump(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('idle hint shown when query is empty', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
        ),
      );
      await _pump(tester);

      expect(
        find.textContaining('Start typing'),
        findsOneWidget,
        reason: 'Idle hint must be visible before any input',
      );

      await _teardown(tester);
    });

    testWidgets('idle hint shown when query is exactly 1 char', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
        ),
      );
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'J');
      await _pump(tester);

      expect(find.textContaining('Start typing'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── 2. Loading state ─────────────────────────────────────────────────────────

  group('CityPickerScreen — loading state', () {
    testWidgets(
      'CircularProgressIndicator shown when citySearch completes future is pending',
      (tester) async {
        // A completer that never resolves keeps provider in AsyncLoading.
        final completer = Completer<List<City>>();

        await tester.pumpWidget(
          _buildApp(
            router: _defaultRouter(),
            locationNotifier: _FakeSacredLocationNotifier(),
            citySearchOverrides: {'Je': (_) => completer.future},
          ),
        );
        // Type query to trigger loading state.
        await tester.enterText(find.byType(TextField), 'Je');
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete([]);
        await _teardown(tester);
      },
    );
  });

  // ── 3. Data state — city list rendered ───────────────────────────────────────

  group('CityPickerScreen — data state', () {
    testWidgets('city names shown as ListTile titles', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Je': (_) async => [_cityJerusalem, _cityTelAviv],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Je');
      await _pump(tester);

      expect(find.text('Jerusalem'), findsOneWidget);
      expect(find.text('Tel Aviv'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('subtitle shows admin1 · countryCode', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Je': (_) async => [_cityJerusalem],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Je');
      await _pump(tester);

      expect(
        find.text('Jerusalem District · IL'),
        findsOneWidget,
        reason: 'Subtitle must join admin1 + countryCode with " · "',
      );

      await _teardown(tester);
    });

    testWidgets('subtitle omits admin1 when it is null', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'No': (_) async => [_cityNoAdmin],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'No');
      await _pump(tester);

      // Subtitle should be just countryCode with no " · " separator.
      expect(find.text('US'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('idle hint disappears once results are shown', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Je': (_) async => [_cityJerusalem],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Je');
      await _pump(tester);

      expect(find.textContaining('Start typing'), findsNothing);

      await _teardown(tester);
    });
  });

  // ── 4. Empty state ───────────────────────────────────────────────────────────

  group('CityPickerScreen — empty state (no matches)', () {
    testWidgets('no-matches message shown when results list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {'Xy': (_) async => []},
        ),
      );
      await tester.enterText(find.byType(TextField), 'Xy');
      await _pump(tester);

      expect(
        find.textContaining('No matches for'),
        findsOneWidget,
        reason: 'Empty state message must be shown',
      );

      await _teardown(tester);
    });

    testWidgets('no-matches message includes the query string', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {'Xy': (_) async => []},
        ),
      );
      await tester.enterText(find.byType(TextField), 'Xy');
      await _pump(tester);

      expect(
        find.textContaining('Xy'),
        findsAtLeast(1),
        reason: 'The query string should appear in the no-matches message',
      );

      await _teardown(tester);
    });
  });

  // ── 5. Error state ───────────────────────────────────────────────────────────

  group('CityPickerScreen — error state', () {
    testWidgets('error message shown when citySearch throws', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            // Retry is null on the generated CitySearchProvider so the error
            // is surfaced immediately without indefinite AsyncLoading.
            'Er': (_) async => throw Exception('db failure'),
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Er');
      await _pump(tester);

      expect(
        find.textContaining('Search failed'),
        findsOneWidget,
        reason:
            'cityPickerSearchErrorGeneric l10n string must be shown on '
            'error',
      );

      await _teardown(tester);
    });

    // AUD-sacred_time-03 (EH-5) — red-first regression: before the fix, this
    // asserted the OPPOSITE (that the raw exception text DID leak through —
    // the exact bug the finding reports). CitiesRepository now converts raw
    // I/O exceptions into a typed CitySearchException before they reach
    // citySearchProvider, and the screen resolves that typed code through
    // AppLocalizations, so the raw exception text must never render.
    testWidgets('error message never includes the raw exception text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Er': (_) async => throw Exception('specific db error'),
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Er');
      await _pump(tester);

      expect(
        find.textContaining('specific db error'),
        findsNothing,
        reason: 'The raw exception message must never reach the UI (EH-5)',
      );
      expect(find.textContaining('Search failed'), findsOneWidget);

      await _teardown(tester);
    });

    // AUD-sacred_time-03 (EH-5) acceptance criterion: a widget test under
    // Locale('he') asserting no raw exception text (e.g. 'Exception:',
    // 'TimeoutException') ever renders.
    testWidgets('he locale: error message never includes raw exception text '
        '(no "Exception:", no "TimeoutException")', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Er': (_) async => throw TimeoutException(
              'Time limit reached while waiting for position update.',
            ),
          },
          locale: const Locale('he'),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Er');
      await _pump(tester);

      expect(find.textContaining('Exception:'), findsNothing);
      expect(find.textContaining('TimeoutException'), findsNothing);
      expect(
        find.textContaining('Time limit reached'),
        findsNothing,
        reason: 'The raw exception message must never reach the UI (EH-5)',
      );
      // The Hebrew generic error string renders instead.
      expect(find.textContaining('החיפוש נכשל'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ── 6. City selection — persistence side-effect ──────────────────────────────

  group('CityPickerScreen — city selection', () {
    testWidgets(
      'tapping a city calls setManualCity with correct lat/lng/label/country',
      (tester) async {
        final locationNotifier = _FakeSacredLocationNotifier();
        await tester.pumpWidget(
          _buildApp(
            router: _defaultRouter(),
            locationNotifier: locationNotifier,
            citySearchOverrides: {
              'Je': (_) async => [_cityJerusalem],
            },
          ),
        );
        await tester.enterText(find.byType(TextField), 'Je');
        await _pump(tester);

        await tester.tap(find.text('Jerusalem'));
        await _pump(tester);

        expect(
          locationNotifier.lastSet,
          isNotNull,
          reason: 'setManualCity must have been called',
        );
        expect(
          locationNotifier.lastSet!.latitude,
          closeTo(_cityJerusalem.latitude, 0.0001),
        );
        expect(
          locationNotifier.lastSet!.longitude,
          closeTo(_cityJerusalem.longitude, 0.0001),
        );
        expect(locationNotifier.lastSet!.countryCode, equals('IL'));
        expect(
          locationNotifier.lastSet!.cityLabel,
          equals('Jerusalem, Jerusalem District, IL'),
        );

        await _teardown(tester);
      },
    );

    testWidgets(
      'tapping a city without admin1 produces label without admin1 segment',
      (tester) async {
        final locationNotifier = _FakeSacredLocationNotifier();
        await tester.pumpWidget(
          _buildApp(
            router: _defaultRouter(),
            locationNotifier: locationNotifier,
            citySearchOverrides: {
              'No': (_) async => [_cityNoAdmin],
            },
          ),
        );
        await tester.enterText(find.byType(TextField), 'No');
        await _pump(tester);

        await tester.tap(find.text('Nomadville'));
        await _pump(tester);

        expect(locationNotifier.lastSet, isNotNull);
        expect(
          locationNotifier.lastSet!.cityLabel,
          equals('Nomadville, US'),
          reason: 'Label must omit admin1 when null',
        );

        await _teardown(tester);
      },
    );

    testWidgets('tapping a city calls router.pop with the chosen City', (
      tester,
    ) async {
      final router = _defaultRouter();
      await tester.pumpWidget(
        _buildApp(
          router: router,
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Je': (_) async => [_cityJerusalem],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Je');
      await _pump(tester);

      await tester.tap(find.text('Jerusalem'));
      await _pump(tester);

      verify(() => router.pop<City>(_cityJerusalem)).called(1);

      await _teardown(tester);
    });
  });

  // ── 7. Product-rule checks ───────────────────────────────────────────────────

  group('CityPickerScreen — product rules', () {
    testWidgets('no track-type label (Personal/Standard/Custom/אישי) shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Je': (_) async => [_cityJerusalem],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Je');
      await _pump(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.textContaining('אישי'), findsNothing);

      await _teardown(tester);
    });
  });

  // ── 8. RTL / Hebrew smoke ────────────────────────────────────────────────────

  group('CityPickerScreen — RTL / Hebrew smoke', () {
    testWidgets('screen pumps without overflow or error under he locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          citySearchOverrides: {
            'Je': (_) async => [_cityJerusalem, _cityTelAviv],
          },
          locale: const Locale('he'),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Je');
      await _pump(tester);

      // No overflow or error widgets.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      await _teardown(tester);
    });

    testWidgets(
      'idle hint renders without overflow under he locale (query < 2)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            router: _defaultRouter(),
            locationNotifier: _FakeSacredLocationNotifier(),
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(ErrorWidget), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets('idle hint shows the localized Hebrew string under he locale, '
        'not the English literal', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: _defaultRouter(),
          locationNotifier: _FakeSacredLocationNotifier(),
          locale: const Locale('he'),
        ),
      );
      await _pump(tester);

      expect(
        find.textContaining('התחילו להקליד'),
        findsOneWidget,
        reason:
            'cityPickerIdleHint must render the Hebrew ARB string '
            'under he locale',
      );
      expect(
        find.textContaining('Start typing'),
        findsNothing,
        reason:
            'The hardcoded English idle-hint literal must not leak '
            'through under he locale',
      );

      await _teardown(tester);
    });
  });
}
