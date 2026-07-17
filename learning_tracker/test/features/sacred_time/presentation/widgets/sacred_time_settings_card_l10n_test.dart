// Regression test for R5 (bug-hunt-round2-findings-2026-05-31.md):
// SacredTimeSettingsCard must render NO hardcoded English — every user-facing
// string must come from AppLocalizations.
//
// Strategy: pump the card under the Hebrew locale and assert that Hebrew
// strings appear where the hardcoded English used to be.  A hardcoded English
// literal would survive even under 'he', so its absence (and the Hebrew string's
// presence) proves the fix.

@Tags(['sacred_time', 'settings_card', 'l10n', 'regression'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fake notifiers ─────────────────────────────────────────────────────────────

class _FakeSacredLocationNotifier extends SacredLocationNotifier {
  final SacredLocation? _initial;
  _FakeSacredLocationNotifier([this._initial]);

  @override
  SacredLocation? build() => _initial; // skip SharedPreferences I/O
}

/// Fake notifier whose [detect] returns a canned [LocationFetchResult] —
/// used to drive the SnackBar rendered by `_LocationActions._showOutcome`
/// without touching real GPS/SharedPreferences.
class _FakeDetectingLocationNotifier extends SacredLocationNotifier {
  _FakeDetectingLocationNotifier(this._result);

  final LocationFetchResult _result;

  @override
  SacredLocation? build() => null; // skip SharedPreferences I/O

  @override
  Future<LocationFetchResult> detect() async => _result;
}

class _FakeInIsraelNotifier extends InIsraelNotifier {
  final bool _initial;
  _FakeInIsraelNotifier(this._initial);

  @override
  bool build() => _initial; // skip SharedPreferences I/O
}

// ── Build helper ───────────────────────────────────────────────────────────────

Widget _buildCard({
  SacredLocation? location,
  bool inIsrael = false,
  Locale locale = const Locale('he'),
  bool? useHebrewTerms,
  TransliterationVariant? variant,
  SacredLocationNotifier? locationNotifierOverride,
}) {
  final locationNotifier =
      locationNotifierOverride ?? _FakeSacredLocationNotifier(location);
  final inIsraelNotifier = _FakeInIsraelNotifier(inIsrael);

  return ProviderScope(
    overrides: [
      sacredLocationProvider.overrideWith(() => locationNotifier),
      inIsraelProvider.overrideWith(() => inIsraelNotifier),
      syncWriteFacadeProvider.overrideWithValue(null),
      if (useHebrewTerms != null)
        useHebrewTermsProvider.overrideWithValue(useHebrewTerms),
      if (variant != null)
        currentTransliterationVariantProvider.overrideWithValue(variant),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SacredTimeSettingsCard()),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Hebrew header ─────────────────────────────────────────────────────────

  group('SacredTimeSettingsCard — Hebrew l10n (no hardcoded English)', () {
    testWidgets(
      'header shows Hebrew mode label (מצב שבת) not English SHABBOS MODE',
      (tester) async {
        await tester.pumpWidget(_buildCard());
        await tester.pump();

        expect(
          find.text('מצב שבת'),
          findsOneWidget,
          reason: 'sacredTimeShabbosModeLabel must render in Hebrew',
        );
        expect(
          find.text('SHABBOS MODE'),
          findsNothing,
          reason: 'hardcoded English must not appear',
        );
      },
    );

    testWidgets(
      'header shows Hebrew "always on" label (תמיד פעיל) not English Always on',
      (tester) async {
        await tester.pumpWidget(_buildCard());
        await tester.pump();

        expect(find.text('תמיד פעיל'), findsOneWidget);
        expect(find.text('Always on'), findsNothing);
      },
    );

    // ── 2. Description paragraph ───────────────────────────────────────────────

    testWidgets('description paragraph renders Hebrew text, not English', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard());
      await tester.pump();

      // Hebrew description starts with 'האפליקציה'
      expect(
        find.textContaining('האפליקציה'),
        findsOneWidget,
        reason: 'sacredTimeCardDescription must render in Hebrew',
      );
      expect(
        find.textContaining('App is silenced'),
        findsNothing,
        reason: 'hardcoded English description must not appear',
      );
    });

    // ── 3. Location row — no location ─────────────────────────────────────────

    testWidgets(
      'location row shows Hebrew "no location set" when location is null',
      (tester) async {
        await tester.pumpWidget(_buildCard());
        await tester.pump();

        expect(
          find.text('לא הוגדר מיקום'),
          findsOneWidget,
          reason: 'sacredTimeNoLocation must render in Hebrew',
        );
        expect(find.text('No location set'), findsNothing);
      },
    );

    // ── 4. In-Israel row ──────────────────────────────────────────────────────

    testWidgets('in-Israel row shows Hebrew title (אני בישראל)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard());
      await tester.pump();

      expect(
        find.text('אני בישראל'),
        findsOneWidget,
        reason: 'sacredTimeInIsraelTitle must render in Hebrew',
      );
      expect(find.text('I am in Israel'), findsNothing);
    });

    // ── 5. Card pumps without ErrorWidget ─────────────────────────────────────

    testWidgets('card renders without error under Hebrew locale', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard());
      await tester.pump();

      expect(find.byType(ErrorWidget), findsNothing);
    });
  });

  // ── 6. Variant-aware Shabbos term (Hebrew-terms toggle + nusach) ───────────
  //
  // The "SHABBOS MODE" header label and the card description embed the
  // variant-aware Shabbos term, resolved via domainTermLabels(ref).shabbos().
  // It must follow the Hebrew-terms toggle + Ashkenazi/Sephardi nusach instead
  // of hardcoding "Shabbos" in the ARB. Rendered under the English locale so
  // the structural frame stays English and only the term varies.
  group('SacredTimeSettingsCard — variant-aware Shabbos term', () {
    testWidgets(
      'Ashkenazi → "SHABBOS MODE" + "...during Shabbos and Yom Tov"',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            locale: const Locale('en'),
            useHebrewTerms: false,
            variant: TransliterationVariant.ashkenazi,
          ),
        );
        await tester.pump();

        expect(find.text('SHABBOS MODE'), findsOneWidget);
        expect(
          find.textContaining('during Shabbos and Yom Tov'),
          findsOneWidget,
        );
        expect(find.text('SHABBAT MODE'), findsNothing);
      },
    );

    testWidgets('Sephardi → "SHABBAT MODE" + "...during Shabbat and Yom Tov"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          locale: const Locale('en'),
          useHebrewTerms: false,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pump();

      expect(find.text('SHABBAT MODE'), findsOneWidget);
      expect(find.textContaining('during Shabbat and Yom Tov'), findsOneWidget);
      expect(find.text('SHABBOS MODE'), findsNothing);
    });

    testWidgets(
      'Hebrew-terms ON under English locale → English frame, Hebrew term '
      '("שבת MODE")',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            locale: const Locale('en'),
            useHebrewTerms: true,
            variant: TransliterationVariant.ashkenazi,
          ),
        );
        await tester.pump();

        // The frame ("{term} MODE") follows the UI locale (English) while the
        // term follows the Hebrew-terms toggle (שבת). toUpperCase is a no-op
        // for Hebrew, so the header reads "שבת MODE".
        expect(find.text('שבת MODE'), findsOneWidget);
        expect(find.text('SHABBOS MODE'), findsNothing);
        expect(find.text('SHABBAT MODE'), findsNothing);
      },
    );

    testWidgets('Hebrew-terms ON under Hebrew locale → "מצב שבת"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          locale: const Locale('he'),
          useHebrewTerms: true,
          variant: TransliterationVariant.ashkenazi,
        ),
      );
      await tester.pump();

      // Hebrew frame "מצב {term}" → "מצב שבת".
      expect(find.text('מצב שבת'), findsOneWidget);
      expect(find.text('SHABBOS MODE'), findsNothing);
    });
  });

  // ── 7. Detect-location error SnackBar — no raw exception text ────────────
  //
  // AUD-sacred_time-03 (EH-5): LocationFetchError now carries a stable
  // LocationErrorCode, never a pre-formatted message. _showOutcome resolves
  // the code through AppLocalizations, so the SnackBar must never contain
  // the underlying exception's raw text — even under the Hebrew locale.
  group(
    'SacredTimeSettingsCard — detect-location error (no raw exception text)',
    () {
      testWidgets(
        'he locale: timeout error SnackBar shows the Hebrew generic string, '
        'never raw exception text',
        (tester) async {
          final locationNotifier = _FakeDetectingLocationNotifier(
            const LocationFetchError(
              LocationErrorCode.timeout,
              debugDetail: 'TimeoutException after 15s GPS timeLimit',
            ),
          );

          await tester.pumpWidget(
            _buildCard(locationNotifierOverride: locationNotifier),
          );
          await tester.pump();

          await tester.tap(find.text('זיהוי אוטומטי'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(find.textContaining('Exception'), findsNothing);
          expect(
            find.textContaining('TimeoutException'),
            findsNothing,
            reason: 'The raw exception text must never reach the UI (EH-5)',
          );
          expect(
            find.textContaining('לא ניתן לזהות מיקום'),
            findsOneWidget,
            reason:
                'sacredTimeLocationDetectErrorTimeout must render in '
                'Hebrew',
          );
        },
      );
    },
  );
}
