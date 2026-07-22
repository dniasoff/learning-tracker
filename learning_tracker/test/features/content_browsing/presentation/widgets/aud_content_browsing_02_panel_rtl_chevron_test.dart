/// AUD-content_browsing-02 regression test — extended by P3-wizard-chevron.
///
/// [HierarchySelectionPanel] renders its OWN inline breadcrumb row (separate
/// from [BreadcrumbNavigation], see the r2_panel_leaf_crumb_ellipsis_test.dart
/// header comment). AUD-content_browsing-02 originally fixed a hardcoded
/// [Icons.chevron_right] on both the breadcrumb separator and the default
/// tile's drill-in disclosure chevron, moving both onto the shared
/// direction-aware `breadcrumbSeparatorIcon` helper.
///
/// The breadcrumb-separator group below is untouched and still passes: that
/// site selects its icon from, and renders under, the SAME (outer) ambient
/// [Directionality] — no wrap sits between selection and render, so there is
/// only ever one mirroring decision.
///
/// The disclosure-chevron group is rewritten by P3-wizard-chevron. The tile
/// this chevron sits on gets independently wrapped in
/// `Directionality(textDirection: rtl)` whenever the (locale-independent)
/// Hebrew Terms display preference is on, purely to reposition the leading
/// checkbox next to a right-to-left label — see hierarchy_selection_panel.dart.
/// `Icon.matchTextDirection` resolves against the NEAREST ambient
/// Directionality at paint time, which is that inner wrap, not whatever
/// ambient the OLD `breadcrumbSeparatorIcon(Directionality.of(context))` call
/// used to pick the icon. So the tile's icon was being selected under one
/// ambient and mirrored under another — a double-flip, invisible to this
/// file's original assertions because `find.byIcon(...)` only checks WHICH
/// glyph was selected, never whether it also got mirrored again at render
/// time. Two real, previously-undetected consequences:
///   - An English-UI (LTR) user with Hebrew Terms on saw this row's chevron
///     point LEFT while step 3 (scope selection)'s visually-identical rows
///     point RIGHT — the P3 "wizard step 3 vs step 7" inconsistency reported
///     across three device-audit runs.
///   - A native Hebrew-UI (RTL) user — where Hebrew Terms is always on, since
///     the toggle is hidden in that locale — saw it backwards too: pointing
///     RIGHT instead of LEFT.
/// Fix (hierarchy_selection_panel.dart): capture the TRUE outer ambient once,
/// before any inner wrap can exist, and pin it explicitly via
/// `Icon(Icons.chevron_right, textDirection: ...)` — `matchTextDirection`
/// then mirrors exactly once, against the direction the app is actually laid
/// out in, immune to the checkbox-repositioning wrap. The icon identity is
/// therefore now ALWAYS `chevron_right`; direction is asserted by checking
/// for the mirroring `Transform` `Icon.build()` applies internally, not by
/// checking which `IconData` constant was used.
///
/// RED before this fix: outer=ltr + Hebrew Terms ON renders the disclosure
/// chevron MIRRORED (pointing left, disagreeing with step 3).
/// GREEN after this fix: outer=ltr + Hebrew Terms ON renders it UNMIRRORED
/// (pointing right, agreeing with step 3); outer=rtl still correctly mirrors
/// (pointing left) regardless of the Hebrew Terms wrap.
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

// P3-wizard-chevron: [textDirection] (the app's real, outer ambient) and
// [useHebrewTerms] (a locale-independent content-display preference) are
// deliberately SEPARATE parameters — the whole point of the bug this file
// now covers is that they can disagree (English UI + Hebrew Terms on is a
// real, reachable combination, not just a test artifact).
Widget _buildPanel({
  required TextDirection textDirection,
  required bool useHebrewTerms,
}) {
  return pumpApp(
    retry: (_, __) => null,
    overrides: [
      useHebrewTermsProvider.overrideWith(
        () => _FixedUseHebrewTerms(useHebrew: useHebrewTerms),
      ),
      currentTransliterationVariantProvider.overrideWith(
        () => _FixedTransliteration(),
      ),
      curriculumContentProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) => Future.value(_containerWithChild())),
    ],
    locale: textDirection == TextDirection.rtl
        ? const Locale('he')
        : const Locale('en'),
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

/// Whether the disclosure chevron [Icon] is rendered mirrored (pointing
/// left) versus in its base drawn orientation (pointing right). Scoped with
/// `find.descendant` (not `find.ancestor` from a bare `RichText`) because the
/// screen also renders label [Text] widgets, which build down to their own
/// `RichText`s — this must only inspect the Transform, if any, that
/// [Icon.build] itself wraps around ITS glyph, not some unrelated ancestor.
bool _disclosureChevronIsMirrored(WidgetTester tester) {
  final iconFinder = find.byIcon(Icons.chevron_right);
  final transformFinder = find.descendant(
    of: iconFinder,
    matching: find.byType(Transform),
  );
  if (transformFinder.evaluate().isEmpty) return false;
  final transform = tester.widget<Transform>(transformFinder.first);
  // Icon.build applies exactly this horizontal-flip matrix when
  // matchTextDirection + rtl; see flutter/lib/src/widgets/icon.dart.
  return transform.transform.storage[0] == -1.0;
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
      await tester.pumpWidget(
        _buildPanel(textDirection: TextDirection.ltr, useHebrewTerms: false),
      );
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
      await tester.pumpWidget(
        _buildPanel(textDirection: TextDirection.rtl, useHebrewTerms: true),
      );
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

  group('P3-wizard-chevron: HierarchySelectionPanel default tile drill-in '
      'disclosure chevron tracks the REAL ambient direction, immune to the '
      'Hebrew-Terms checkbox-repositioning wrap', () {
    testWidgets(
      'outer=ltr, Hebrew Terms OFF: chevron_right, unmirrored (baseline, '
      'matches step 3)',
      (tester) async {
        await tester.pumpWidget(
          _buildPanel(textDirection: TextDirection.ltr, useHebrewTerms: false),
        );
        await _settle(tester);

        // Before drilling in, only the top-level container tile's
        // disclosure chevron is on screen (no breadcrumb yet).
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left), findsNothing);
        expect(
          _disclosureChevronIsMirrored(tester),
          isFalse,
          reason: 'outer=ltr with no Hebrew-Terms wrap must point right.',
        );

        expect(tester.takeException(), isNull);
        await _teardown(tester);
      },
    );

    testWidgets('outer=ltr, Hebrew Terms ON: chevron_right, unmirrored — THE '
        'REPORTED P3 (step 3 vs step 7 disagreed; both now point right)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(textDirection: TextDirection.ltr, useHebrewTerms: true),
      );
      await _settle(tester);

      // Still always chevron_right — chevron_left is never selected any
      // more; direction comes solely from the mirror transform.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(
        _disclosureChevronIsMirrored(tester),
        isFalse,
        reason:
            'P3-wizard-chevron: the app is laid out LTR (English UI) — '
            'the Hebrew Terms preference changes label language/checkbox '
            'position, not the app\'s reading direction, so the '
            'drill-in chevron must still point RIGHT, agreeing with '
            'step 3\'s scope-selection rows. Before the fix this was '
            'MIRRORED (pointing left), which is the exact "step 3 right, '
            'step 7 left" inconsistency reported across three device '
            'audits.',
      );

      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });

    testWidgets('outer=rtl, Hebrew Terms ON (native Hebrew UI — the toggle is '
        'always on here): chevron_right selected, MIRRORED to point left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(textDirection: TextDirection.rtl, useHebrewTerms: true),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(
        _disclosureChevronIsMirrored(tester),
        isTrue,
        reason:
            'P3-wizard-chevron: native RTL must mirror to point LEFT. '
            'Before the fix, breadcrumbSeparatorIcon selected '
            'chevron_left here (correct-looking by identity alone), but '
            'the Hebrew-Terms wrap then mirrored it AGAIN, rendering it '
            'backwards (pointing right) — invisible to the old '
            'find.byIcon(chevron_left) assertion, since selecting the '
            'icon and mirroring it are two different steps.',
      );

      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });

    testWidgets('outer=rtl, Hebrew Terms OFF: still mirrored to point left — '
        'direction tracks the real ambient, not the Hebrew-Terms flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(textDirection: TextDirection.rtl, useHebrewTerms: false),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(
        _disclosureChevronIsMirrored(tester),
        isTrue,
        reason:
            'No Hebrew-Terms wrap exists in this case, yet the app '
            'itself is laid out RTL, so the chevron must still mirror — '
            'proving direction is driven by the real ambient Directionality '
            'captured at selection time, not by whether the '
            'checkbox-repositioning wrap happens to apply.',
      );

      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });
  });
}
