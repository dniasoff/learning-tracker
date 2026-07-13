/// Regression test for AUD-gamification-04 (AX-3): the back-navigation
/// IconButton on [RewardConfigHeader] had no `tooltip`/`semanticLabel`, so
/// TalkBack/VoiceOver users reached the control with no announced purpose —
/// unlike the adjacent [PopupMenuButton], which gets a Flutter-provided
/// default tooltip.
///
/// The EN test exercises the finding's literal AC ("a widget test finds a
/// Semantics node with a non-empty label for the back button via
/// find.bySemanticsLabel or tester.getSemantics"). The HE test is a proxy
/// for a manual TalkBack/VoiceOver pass, asserting the semantics tree — the
/// exact data assistive services consume — carries the localized label in
/// the Hebrew build too.
///
/// NOTE: `IconButton(tooltip: ...)` alone does NOT satisfy this AC on the
/// current Flutter SDK (3.44.6) — `Tooltip`/`RawTooltip` now populate
/// `SemanticsData.tooltip`, not `SemanticsData.label` (see
/// packages/flutter/lib/src/widgets/raw_tooltip.dart `semanticsTooltip`).
/// `find.bySemanticsLabel` and `SemanticsNode.label` only see the `label`
/// field, so the fix additionally sets `Icon(semanticLabel: ...)`, which the
/// framework surfaces as `Semantics(label: ...)` (AX-3's named mechanism).
@Tags(['gamification', 'a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_config_header.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _build({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RewardConfigHeader(
        topInset: 0,
        title: 'Configure Rewards',
        onBack: () {},
        onMenuSelected: (_) {},
      ),
    ),
  );
}

Future<void> _tearDown(WidgetTester tester, SemanticsHandle handle) async {
  handle.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  group('RewardConfigHeader — AUD-gamification-04: back button a11y', () {
    testWidgets('EN: back IconButton exposes a non-empty Semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_build());
      await tester.pump();

      // Target the back button specifically — PopupMenuButton also renders
      // an internal IconButton, so a bare find.byType(IconButton) matches
      // both.
      final backButton = find.widgetWithIcon(
        IconButton,
        Icons.arrow_back_ios_new_rounded,
      );
      expect(backButton, findsOneWidget);

      // AC (literal): tester.getSemantics on the back button must show a
      // non-empty label.
      final semantics = tester.getSemantics(backButton);
      expect(
        semantics.label,
        isNotEmpty,
        reason:
            'AUD-gamification-04: the icon-only back button must expose a '
            'non-empty semantic label so TalkBack/VoiceOver announce its '
            'purpose.',
      );
      expect(semantics.label, 'Back');

      // AC (literal, alt form): find.bySemanticsLabel must also locate it.
      expect(find.bySemanticsLabel('Back'), findsOneWidget);

      await _tearDown(tester, handle);
    });

    testWidgets(
      'HE: back IconButton exposes the Hebrew MaterialLocalizations label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_build(locale: const Locale('he')));
        await tester.pump();

        // Flutter's own MaterialLocalizations back-button string ("הקודם")
        // must be exposed on the semantics tree in the Hebrew build too —
        // not the English default leaking through.
        expect(
          find.bySemanticsLabel('הקודם'),
          findsOneWidget,
          reason:
              'AUD-gamification-04: the Hebrew back-button label must be '
              'exposed on the semantics tree, not an English leak.',
        );

        await _tearDown(tester, handle);
      },
    );
  });
}
