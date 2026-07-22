/// R2/overflow (device 5558) regression — Add-Track wizard Step 7 CTA.
///
/// Step 7 of the Add-Track flow ([SelfPacedPriorProgressStep]) renders a
/// [HierarchySelectionPanel] in its default Skip / Confirm mode, where the
/// confirm label is `l10n.actionMarkCompleted` ("Mark Completed"). Both buttons
/// live in equal-flex [Expanded] cells, so on a narrow phone the confirm button
/// only gets ~half the row width. Previously the label was a bare [Text] with
/// `TextOverflow.ellipsis`, so "Mark Completed" was clipped to "Mark Complet…".
///
/// RED before the fix: at a 320-wide viewport the confirm label's
/// [RenderParagraph] exceeded its single line (`didExceedMaxLines == true`) and
/// was ellipsized.
/// GREEN after: the label is wrapped in a `FittedBox(fit: BoxFit.scaleDown)`, so
/// it lays out at its natural single-line width and is scaled down to fit rather
/// than clipped — `didExceedMaxLines == false` — at default and larger text
/// scales, in LTR and RTL.
@Tags(['content_browsing', 'r2'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/overflow_harness.dart';

// The two confirm labels the wizard actually renders (see app_en.arb /
// app_he.arb `actionMarkCompleted`). Kept as literals so the regression is
// pinned to the exact multi-word CTA that clipped on device 5558.
const _confirmEn = 'Mark Completed';
const _confirmHe = 'סמן כהושלם';

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

// A single leaf so the browser lands on the data state immediately (no drill
// needed — the Skip / Confirm row renders regardless of selection).
List<ContentItem> _singleLeaf() => const [
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    displayNameHe: 'זרעים',
    displayNameEn: 'Zeraim',
    sefariaRef: 'zeraim',
    sortOrder: 0,
    isLeaf: true,
  ),
];

List<Override> _overrides({required bool useHebrew}) => [
  useHebrewTermsProvider.overrideWith(
    () => _FixedUseHebrewTerms(useHebrew: useHebrew),
  ),
  currentTransliterationVariantProvider.overrideWith(
    () => _FixedTransliteration(),
  ),
  curriculumContentProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) => Future.value(_singleLeaf())),
];

// Reproduces the step-7 wiring: default Skip / Confirm mode with the
// "Mark Completed" confirm label, both callbacks non-null so both buttons show.
Widget _panel({required String confirmLabel}) => HierarchySelectionPanel(
  curriculumId: CurriculumId.mishnayos,
  onSkip: () {},
  onConfirmed: (_) {},
  confirmLabel: confirmLabel,
  autoAdvanceSingleOption: false,
);

Widget _harnessedPanel({
  required double textScale,
  required TextDirection textDirection,
  required String confirmLabel,
}) {
  final useHebrew = textDirection == TextDirection.rtl;
  return ProviderScope(
    retry: (_, __) => null,
    overrides: _overrides(useHebrew: useHebrew),
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
      // Narrow phone width (device-5558 class) so the confirm label cannot
      // simply fit at full size in its half-row Expanded cell.
      home: Scaffold(
        body: SizedBox(width: 320, child: _panel(confirmLabel: confirmLabel)),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final textDirection in [TextDirection.ltr, TextDirection.rtl]) {
    final dirName = textDirection == TextDirection.ltr ? 'LTR' : 'RTL';
    final confirmLabel = textDirection == TextDirection.ltr
        ? _confirmEn
        : _confirmHe;

    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'F/CTA: $dirName @scale $scale — "$confirmLabel" is not clipped',
        (tester) async {
          await tester.pumpWidget(
            _harnessedPanel(
              textScale: scale,
              textDirection: textDirection,
              confirmLabel: confirmLabel,
            ),
          );
          await _settle(tester);

          final labelFinder = find.text(confirmLabel);
          expect(
            labelFinder,
            findsOneWidget,
            reason: 'the confirm CTA label must render',
          );

          // Behavioural: the label lays out on a single line at its natural
          // width and is NOT truncated. Before the fix the bounded half-row
          // Expanded forced ellipsis (didExceedMaxLines == true → "Mark
          // Complet…"); with the FittedBox it renders unbounded and full.
          final paragraph = tester.renderObject<RenderParagraph>(labelFinder);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason:
                '$dirName @scale $scale: "$confirmLabel" must render in full, '
                'not be clipped/ellipsized',
          );

          // Structural guard: the label sits inside a scale-down FittedBox so a
          // future revert to a bare ellipsis Text is caught.
          expect(
            find.ancestor(
              of: labelFinder,
              matching: find.byWidgetPredicate(
                (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
              ),
            ),
            findsOneWidget,
            reason: 'confirm label must be wrapped in a scale-down FittedBox',
          );

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'F/CTA: Skip + Mark-Completed row never RenderFlex-overflows across '
    'the device matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => SizedBox(width: 320, child: _panel(confirmLabel: _confirmEn)),
        overrides: _overrides(useHebrew: false),
      );
    },
  );
}
