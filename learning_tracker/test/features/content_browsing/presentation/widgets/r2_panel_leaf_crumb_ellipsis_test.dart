/// R2 finding 5 (P2) regression — HierarchySelectionPanel's inline breadcrumb.
///
/// The panel renders its OWN inline breadcrumb (separate from
/// [BreadcrumbNavigation]). The current/leaf crumb — the last, non-clickable
/// segment — was a bare [Text] inside a horizontal [SingleChildScrollView] with
/// no maxLines / overflow, so a long label at font scale 1.3 ran off the scroll
/// viewport edge and was hard-clipped mid-word (worse in RTL).
///
/// RED before the fix: the leaf crumb [Text] had `overflow == null` and was not
/// wrapped in a [ConstrainedBox] — it could clip mid-glyph.
/// GREEN after: the leaf crumb is constrained to the bounded viewport width
/// (via a [LayoutBuilder] outside the scroll view) and uses
/// [TextOverflow.ellipsis] with `maxLines: 1`, so it is never cut mid-word in
/// either LTR or RTL, at font scale 1.0 or 1.3.
@Tags(['content_browsing', 'breadcrumb', 'r2'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// A very long top-level (named Seder) container name — when we drill into it,
// it becomes the current/leaf crumb that must ellipsize rather than clip.
const _longSederEn =
    'Seder Zeraim With A Very Long Name That Overflows The Breadcrumb Width';
const _longSederHe =
    'סדר זרעים עם שם ארוך מאוד שגולש מעבר לרוחב הברירמב הזמין על המסך';

class _FixedUseHebrewTerms extends UseHebrewTerms {
  _FixedUseHebrewTerms({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

class _FixedTransliteration extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.sephardi;
}

/// One long-named container with one child leaf, so drilling in produces a
/// single-segment navigation stack whose leaf crumb is the long name.
List<ContentItem> _longContainerWithChild() => const [
  ContentItem(
    curriculumId: 'mishnayos',
    level1: _longSederEn,
    displayNameHe: _longSederHe,
    displayNameEn: _longSederEn,
    sefariaRef: 'long_seder',
    sortOrder: 0,
    isLeaf: false,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: _longSederEn,
    level2: 'Berachos',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berachos',
    sefariaRef: 'long_seder_berachos',
    sortOrder: 1,
    isLeaf: true,
  ),
];

Widget _buildPanel({
  required double textScale,
  required TextDirection textDirection,
}) {
  final useHebrew = textDirection == TextDirection.rtl;
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      useHebrewTermsProvider.overrideWith(
        () => _FixedUseHebrewTerms(useHebrew: useHebrew),
      ),
      currentTransliterationVariantProvider.overrideWith(
        () => _FixedTransliteration(),
      ),
      curriculumContentProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) => Future.value(_longContainerWithChild())),
    ],
    child: MaterialApp(
      locale: useHebrew ? const Locale('he') : const Locale('en'),
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
        // Narrow phone width so the long current crumb cannot simply fit —
        // it must rely on ellipsis.
        body: SizedBox(
          width: 320,
          child: HierarchySelectionPanel(
            curriculumId: CurriculumId.mishnayos,
            onConfirmed: (_) {},
            autoAdvanceSingleOption: false,
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// The leaf crumb is the last (non-clickable) TextButton in the breadcrumb row.
Text _leafCrumbText(WidgetTester tester) {
  // The breadcrumb row's TextButtons: [curriculum-root, ...crumbs]. The leaf
  // crumb is the last one and has a null onPressed.
  final buttons = tester
      .widgetList<TextButton>(find.byType(TextButton))
      .toList();
  final leafButton = buttons.lastWhere((b) => b.onPressed == null);
  final leafTextFinder = find.descendant(
    of: find.byWidget(leafButton),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(leafTextFinder.first);
}

Future<void> _drillIntoLongContainer(WidgetTester tester) async {
  // Tap the single top-level container tile to drill in and populate the
  // breadcrumb. Tapping the ListTile is direction-agnostic (the rendered label
  // differs between LTR English and RTL Hebrew because the renderer strips
  // structural prefixes in Hebrew mode).
  await tester.tap(find.byType(ListTile).first);
  await _settle(tester);
}

void main() {
  for (final textDirection in [TextDirection.ltr, TextDirection.rtl]) {
    final dirName = textDirection == TextDirection.ltr ? 'LTR' : 'RTL';

    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'R2: $dirName @scale $scale — leaf crumb ellipsizes, never clips '
        'mid-word',
        (tester) async {
          await tester.pumpWidget(
            _buildPanel(textScale: scale, textDirection: textDirection),
          );
          await _settle(tester);

          await _drillIntoLongContainer(tester);

          // A breadcrumb must now be present.
          expect(
            find.byType(TextButton),
            findsWidgets,
            reason: 'drilling in must render the breadcrumb',
          );

          final leaf = _leafCrumbText(tester);
          expect(
            leaf.overflow,
            TextOverflow.ellipsis,
            reason:
                '$dirName @scale $scale: the current/leaf crumb must '
                'ellipsize, not clip mid-word',
          );
          expect(leaf.maxLines, 1);

          // It must be bounded by a *real* width cap so the ellipsis
          // actually engages instead of running unbounded under the
          // horizontal scroll viewport. `find.byType(ConstrainedBox)` alone
          // is NOT sufficient: TextButton wraps its child in its own
          // ConstrainedBox for the Material minimum tap-target size
          // (minWidth: 64, maxWidth: double.infinity), which satisfies an
          // unqualified ancestor lookup even if the fix's width cap were
          // removed. Require a finite maxWidth so only the actual
          // width-cap box (not TextButton's unrelated min-size box) can
          // match.
          expect(
            find.ancestor(
              of: find.byWidget(leaf),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is ConstrainedBox &&
                    w.constraints.maxWidth < double.infinity,
              ),
            ),
            findsWidgets,
            reason:
                '$dirName @scale $scale: leaf crumb must be width-capped '
                '(finite maxWidth) so ellipsis engages — a ConstrainedBox '
                "with an unbounded maxWidth (e.g. TextButton's own "
                'min-tap-target box) does not satisfy this',
          );

          // No render-overflow exceptions should have been thrown.
          expect(tester.takeException(), isNull);

          await _teardown(tester);
        },
      );
    }
  }
}
