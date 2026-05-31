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
}) {
  final locationNotifier = _FakeSacredLocationNotifier(location);
  final inIsraelNotifier = _FakeInIsraelNotifier(inIsrael);

  return ProviderScope(
    overrides: [
      sacredLocationProvider.overrideWith(() => locationNotifier),
      inIsraelProvider.overrideWith(() => inIsraelNotifier),
      syncWriteFacadeProvider.overrideWithValue(null),
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
}
