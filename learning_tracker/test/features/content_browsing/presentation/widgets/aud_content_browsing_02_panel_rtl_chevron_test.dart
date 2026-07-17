/// AUD-content_browsing-02 regression test.
///
/// [HierarchySelectionPanel] renders its OWN inline breadcrumb row (separate
/// from [BreadcrumbNavigation], see the r2_panel_leaf_crumb_ellipsis_test.dart
/// header comment) but hardcoded [Icons.chevron_right] for the separator
/// between crumbs instead of reusing the shared direction-aware
/// `breadcrumbSeparatorIcon` helper. In RTL (Hebrew terms mode) the trail
/// reads right-to-left, so a right-pointing chevron points the wrong reading
/// direction — the same bug already fixed in the sibling [BreadcrumbNavigation]
/// widget (IL-7 / R2 finding 4).
///
/// The panel's default tile builder had the identical bare-chevron pattern for
/// its drill-in disclosure indicator (the AC-2 file-wide grep covers both
/// sites), so this file also locks in that the disclosure chevron flips.
///
/// RED before the fix: RTL layout renders [Icons.chevron_right] (0 instances
/// of [Icons.chevron_left] in the breadcrumb row).
/// GREEN after the fix: RTL layout renders [Icons.chevron_left]; LTR keeps
/// [Icons.chevron_right].
@Tags(['content_browsing', 'breadcrumb', 'rtl', 'ax-3'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';

import '../../../../helpers/pump_app.dart';

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

// One container with one child leaf, so drilling in produces a single-segment
// navigation stack — enough to render exactly one separator chevron.
List<ContentItem> _containerWithChild() => const [
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    displayNameHe: 'סדר זרעים',
    displayNameEn: 'Seder Zeraim',
    sefariaRef: 'seder_zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berachos',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berachos',
    sefariaRef: 'seder_zeraim_berachos',
    sortOrder: 1,
    isLeaf: true,
  ),
];

Widget _buildPanel({required TextDirection textDirection}) {
  final useHebrew = textDirection == TextDirection.rtl;
  return pumpApp(
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
      ).overrideWith((ref) => Future.value(_containerWithChild())),
    ],
    locale: useHebrew ? const Locale('he') : const Locale('en'),
    builder: (context, child) =>
        Directionality(textDirection: textDirection, child: child!),
    child: Scaffold(
      body: HierarchySelectionPanel(
        curriculumId: CurriculumId.mishnayos,
        onConfirmed: (_) {},
        autoAdvanceSingleOption: false,
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

Future<void> _drillIntoContainer(WidgetTester tester) async {
  await tester.tap(find.byType(ListTile).first);
  await _settle(tester);
}

void main() {
  group('AUD-content_browsing-02: HierarchySelectionPanel inline breadcrumb '
      'separator is direction-aware', () {
    testWidgets('LTR layout uses chevron_right separator', (tester) async {
      await tester.pumpWidget(_buildPanel(textDirection: TextDirection.ltr));
      await _settle(tester);

      await _drillIntoContainer(tester);

      expect(
        find.byIcon(Icons.chevron_right),
        findsOneWidget,
        reason:
            'AUD-content_browsing-02: LTR layout must use chevron_right '
            'separator.',
      );
      expect(
        find.byIcon(Icons.chevron_left),
        findsNothing,
        reason:
            'AUD-content_browsing-02: LTR layout must NOT use chevron_left '
            'separator.',
      );

      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });

    testWidgets('RTL layout uses chevron_left separator (Hebrew terms mode)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPanel(textDirection: TextDirection.rtl));
      await _settle(tester);

      await _drillIntoContainer(tester);

      expect(
        find.byIcon(Icons.chevron_left),
        findsOneWidget,
        reason:
            'AUD-content_browsing-02: RTL layout must use chevron_left '
            'separator, not chevron_right which reads in the wrong '
            'direction.',
      );
      expect(
        find.byIcon(Icons.chevron_right),
        findsNothing,
        reason:
            'AUD-content_browsing-02: RTL layout must NOT use '
            'chevron_right separator.',
      );

      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });
  });

  group('AUD-content_browsing-02: HierarchySelectionPanel default tile '
      'drill-in disclosure chevron is direction-aware', () {
    testWidgets('LTR layout uses chevron_right on the container tile', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPanel(textDirection: TextDirection.ltr));
      await _settle(tester);

      // Before drilling in, only the top-level container tile's disclosure
      // chevron is on screen (no breadcrumb yet).
      expect(
        find.byIcon(Icons.chevron_right),
        findsOneWidget,
        reason:
            'AUD-content_browsing-02: LTR container tile must use '
            'chevron_right for its drill-in disclosure indicator.',
      );
      expect(find.byIcon(Icons.chevron_left), findsNothing);

      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });

    testWidgets(
      'RTL layout uses chevron_left on the container tile (Hebrew terms '
      'mode)',
      (tester) async {
        await tester.pumpWidget(_buildPanel(textDirection: TextDirection.rtl));
        await _settle(tester);

        expect(
          find.byIcon(Icons.chevron_left),
          findsOneWidget,
          reason:
              'AUD-content_browsing-02: RTL container tile must use '
              'chevron_left for its drill-in disclosure indicator, not '
              'chevron_right which reads in the wrong direction.',
        );
        expect(find.byIcon(Icons.chevron_right), findsNothing);

        expect(tester.takeException(), isNull);
        await _teardown(tester);
      },
    );
  });
}
