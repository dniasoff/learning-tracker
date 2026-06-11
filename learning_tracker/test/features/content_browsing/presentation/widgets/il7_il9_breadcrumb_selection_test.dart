/// IL-7 + IL-9 regression tests:
///
/// IL-7: BreadcrumbNavigation must use direction-aware chevron separators —
///       chevron_right in LTR, chevron_left in RTL (Hebrew terms mode).
///
/// IL-9: HierarchySelectionPanel must use a localized selection-count string
///       instead of the raw hardcoded English literal "selection(s)".
///
/// RED → GREEN cycle:
///   IL-7 RED:  RTL layout shows chevron_right (wrong direction).
///   IL-7 GREEN: RTL layout shows chevron_left.
///   IL-9 RED:  selection count shows raw "selection(s)" literal.
///   IL-9 GREEN: AppLocalizations.selectionCount(n) is used.
@Tags(['content_browsing', 'il7', 'il9'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _buildBreadcrumb({
  required TextDirection textDirection,
  required List<String> stack,
}) {
  return Directionality(
    textDirection: textDirection,
    child: MaterialApp(
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
      // Override directionality for the entire app.
      builder: (context, child) =>
          Directionality(textDirection: textDirection, child: child!),
      home: Scaffold(
        body: BreadcrumbNavigation(
          curriculum: CurriculumId.mishnayos,
          levelLabels: const ['Seder', 'Masechta'],
          navigationStack: stack,
          onBreadcrumbTap: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('IL-7 direction-aware breadcrumb chevron', () {
    testWidgets('LTR layout uses chevron_right separator', (tester) async {
      await tester.pumpWidget(
        _buildBreadcrumb(
          textDirection: TextDirection.ltr,
          stack: const ['Seder Zeraim', 'Berachos'],
        ),
      );
      await tester.pump();

      // LTR → chevron_right
      expect(
        find.byIcon(Icons.chevron_right),
        findsOneWidget,
        reason: 'IL-7: LTR layout must use chevron_right separator.',
      );
      expect(
        find.byIcon(Icons.chevron_left),
        findsNothing,
        reason: 'IL-7: LTR layout must NOT use chevron_left separator.',
      );
    });

    testWidgets('RTL layout uses chevron_left separator (Hebrew terms mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildBreadcrumb(
          textDirection: TextDirection.rtl,
          stack: const ['סדר זרעים', 'ברכות'],
        ),
      );
      await tester.pump();

      // RTL → chevron_left
      expect(
        find.byIcon(Icons.chevron_left),
        findsOneWidget,
        reason:
            'IL-7: RTL layout must use chevron_left separator, not '
            'chevron_right which inverts the visual hierarchy.',
      );
      expect(
        find.byIcon(Icons.chevron_right),
        findsNothing,
        reason: 'IL-7: RTL layout must NOT use chevron_right separator.',
      );
    });
  });

  group('IL-9 localized selection count', () {
    /// Unit test: AppLocalizations.selectionCount returns localized plural form.
    testWidgets(
      'l10n.selectionCount(1) returns singular form, not raw "selection(s)"',
      (tester) async {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context)!;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        // Must NOT contain the raw literal "selection(s)".
        final single = l10n.selectionCount(1);
        final plural = l10n.selectionCount(3);

        expect(
          single,
          isNot(contains('selection(s)')),
          reason:
              'IL-9: selectionCount(1) must use a localized singular form, '
              'not the raw "selection(s)" literal.',
        );
        expect(
          single,
          contains('selection'),
          reason: 'IL-9: selectionCount(1) must contain the word "selection".',
        );
        expect(
          plural,
          contains('selections'),
          reason:
              'IL-9: selectionCount(3) must use the plural form "selections".',
        );

        // Hebrew form must not be Latin.
        late AppLocalizations heL10n;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('he'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                heL10n = AppLocalizations.of(context)!;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        final heSingle = heL10n.selectionCount(1);
        expect(
          heSingle,
          isNot(contains('selection(s)')),
          reason:
              'IL-9: Hebrew selectionCount must not use the raw Latin '
              '"selection(s)" literal.',
        );
      },
    );
  });
}
