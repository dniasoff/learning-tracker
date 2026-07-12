// L1 widget test — ChazaraInlineSetup (AUD-tracks-03)
//
// Covers:
//   1. English locale: the four built-in preset cards render their EN titles
//      (Learn Only / 1 day / 1 + 7 days / 1 + 7 + 30 days) via AppLocalizations,
//      confirming the switch to l10n keys did not silently break the EN copy.
//   2. Hebrew locale: none of the four preset card titles/subtitles render in
//      Latin script — guards against the hardcoded-English regression this
//      finding fixed (AX-2 — every displayed string comes from AppLocalizations
//      with EN/HE key parity).
//
// PUMP RIG mirrors step_chazara_goal_l1_test.dart:
//   ProviderScope(retry:(_, __)=>null,
//     child: MaterialApp(locale, 4 l10n delegates, home: Scaffold(body:...)))

@Tags(['tracks', 'steps', 'chazara', 'l1', 'i18n'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/chazara_widgets.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _kDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Matches any Latin-alphabet letter (A-Z, a-z) — used to detect English
/// literals leaking into a Hebrew-locale render.
final _latinLetter = RegExp('[A-Za-z]');

Widget _buildApp({Locale locale = const Locale('en')}) {
  return ProviderScope(
    retry: (_, __) => null,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 900,
          child: ChazaraInlineSetup(
            curriculumId: CurriculumId.mishnayos,
            headerTitle: 'Review Setup',
            headerSubtitle: 'Choose a schedule',
            onComplete: (_) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ChazaraInlineSetup — preset cards localization', () {
    testWidgets('English locale: four preset cards render EN copy via l10n', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await _settle(tester);

      final cards = tester.widgetList<ReviewPresetCard>(
        find.byType(ReviewPresetCard),
      );
      expect(cards.length, equals(4));

      final titles = cards.map((c) => c.title).toList();
      expect(
        titles,
        containsAll(<String>[
          'Learn Only',
          '1 day',
          '1 + 7 days',
          '1 + 7 + 30 days',
        ]),
      );

      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'Hebrew locale: none of the four preset card texts render in Latin script',
      (tester) async {
        await tester.pumpWidget(_buildApp(locale: const Locale('he')));
        await _settle(tester);

        final cards = tester.widgetList<ReviewPresetCard>(
          find.byType(ReviewPresetCard),
        );
        expect(cards.length, equals(4));

        for (final card in cards) {
          expect(
            _latinLetter.hasMatch(card.title),
            isFalse,
            reason:
                'Preset title "${card.title}" must not contain Latin '
                'letters under Locale(he)',
          );
          expect(
            _latinLetter.hasMatch(card.subtitle),
            isFalse,
            reason:
                'Preset subtitle "${card.subtitle}" must not contain Latin '
                'letters under Locale(he)',
          );
        }

        addTearDown(() => _tearDown(tester));
      },
    );
  });
}
