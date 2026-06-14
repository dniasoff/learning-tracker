/// R2 finding 5 regression: the active/current breadcrumb crumb must ellipsize
/// cleanly instead of being clipped mid-word at large text scales (font scale
/// 1.3, worse in RTL — e.g. 'Berakhos' truncating mid-word).
///
/// RED before the fix: the current crumb was a bare [Text] with no maxLines /
/// overflow, so a long label at scale 1.3 ran off the scroll viewport edge and
/// was hard-clipped mid-glyph.
/// GREEN after: the current crumb is constrained to the available width and
/// uses [TextOverflow.ellipsis] (maxLines: 1), so it is never cut mid-word.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _host({
  required TextDirection textDirection,
  required List<String> stack,
  double textScale = 1.3,
}) {
  return MaterialApp(
    locale: textDirection == TextDirection.rtl
        ? const Locale('he')
        : const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => Directionality(
      textDirection: textDirection,
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
    ),
    home: Scaffold(
      // Constrain to a narrow phone width so the long current crumb cannot
      // simply fit on screen — it must rely on ellipsis.
      body: SizedBox(
        width: 320,
        child: BreadcrumbNavigation(
          curriculum: CurriculumId.mishnayos,
          levelLabels: const ['Seder', 'Masechta'],
          navigationStack: stack,
          onBreadcrumbTap: (_) {},
        ),
      ),
    ),
  );
}

Text _currentCrumbText(WidgetTester tester, String label) {
  return tester.widget<Text>(find.text(label));
}

void main() {
  group('R2 finding 5 — current crumb never clipped mid-word at scale 1.3', () {
    testWidgets('LTR: long current crumb ellipsizes (maxLines 1, ellipsis)', (
      tester,
    ) async {
      const longLabel =
          'Berakhos and a very long masechta name that overflows the width';
      await tester.pumpWidget(
        _host(
          textDirection: TextDirection.ltr,
          stack: const ['Seder Zeraim', longLabel],
        ),
      );
      await tester.pump();

      expect(find.text(longLabel), findsOneWidget);
      final text = _currentCrumbText(tester, longLabel);
      expect(
        text.overflow,
        TextOverflow.ellipsis,
        reason: 'current crumb must ellipsize, not clip mid-word',
      );
      expect(text.maxLines, 1);

      // It must be bounded by a ConstrainedBox (the width cap) so the ellipsis
      // actually engages instead of the Text running unbounded under the scroll
      // viewport.
      expect(
        find.ancestor(
          of: find.text(longLabel),
          matching: find.byType(ConstrainedBox),
        ),
        findsWidgets,
      );

      // No render overflow exceptions should have been thrown.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'RTL: long Hebrew current crumb ellipsizes (no mid-word clip)',
      (tester) async {
        const longHe = 'ברכות מסכת ארוכה מאוד שגולשת מעבר לרוחב המסך הזמין כאן';
        await tester.pumpWidget(
          _host(
            textDirection: TextDirection.rtl,
            stack: const ['סדר זרעים', longHe],
          ),
        );
        await tester.pump();

        final text = _currentCrumbText(tester, longHe);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
