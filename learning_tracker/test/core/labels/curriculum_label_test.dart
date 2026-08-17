import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget wrap(
    Widget child, {
    bool hebrewTermsScript = true,
    TransliterationVariant? variant,
    List<Override> overrides = const [],
  }) {
    SharedPreferences.setMockInitialValues({
      'hebrew_terms_script_p0': hebrewTermsScript,
    });
    return ProviderScope(
      overrides: [
        useHebrewTermsProvider.overrideWithValue(hebrewTermsScript),
        if (variant != null)
          currentTransliterationVariantProvider.overrideWithValue(variant),
        ...overrides,
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('CurriculumLabel.curriculum', () {
    testWidgets('Hebrew terms ON → displayNameHe', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.mishnayos),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('Mishnayos'), findsNothing);
    });

    testWidgets('Hebrew terms OFF, Ashkenazi → "Mishnayos"', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.mishnayos),
          hebrewTermsScript: false,
          variant: TransliterationVariant.ashkenazi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Mishnayot'), findsNothing);
      expect(find.text('משניות'), findsNothing);
    });

    testWidgets('Hebrew terms OFF, Sephardi → "Mishnayot"', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.mishnayos),
          hebrewTermsScript: false,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mishnayot'), findsOneWidget);
      expect(find.text('Mishnayos'), findsNothing);
      expect(find.text('משניות'), findsNothing);
    });

    testWidgets('Tanach: Ashkenazi "Tanach" vs Sephardi "Tanakh"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.tanach),
          hebrewTermsScript: false,
          variant: TransliterationVariant.ashkenazi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tanach'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.tanach),
          hebrewTermsScript: false,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tanakh'), findsOneWidget);
      expect(find.text('Tanach'), findsNothing);
    });

    testWidgets('Nach: Ashkenazi "Nach" vs Sephardi "Nakh"', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.nach),
          hebrewTermsScript: false,
          variant: TransliterationVariant.ashkenazi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nach'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.nach),
          hebrewTermsScript: false,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nakh'), findsOneWidget);
      expect(find.text('Nach'), findsNothing);
    });

    testWidgets(
      'nusach-invariant curriculum (Talmud Bavli) is identical in both',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const CurriculumLabel.curriculum(CurriculumId.bavli),
            hebrewTermsScript: false,
            variant: TransliterationVariant.sephardi,
          ),
        );
        await tester.pumpAndSettle();
        // Falls through transliterateNamedValue to the raw Ashkenazi value.
        expect(find.text('Talmud Bavli'), findsOneWidget);
      },
    );

    testWidgets('Sephardi + Hebrew terms ON still renders Hebrew', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.mishnayos),
          hebrewTermsScript: true,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('Mishnayot'), findsNothing);
    });
  });

  group(
    'CurriculumLabel.level — ordinal levels (no parent-name repetition)',
    () {
      testWidgets('Mishnayos Perek 1 Hebrew → "פרק א" (not "משנה דמאי א")', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const CurriculumLabel.level(
              curriculumId: CurriculumId.mishnayos,
              level: 3, // Seder / Masechta / Perek / Mishna
              rawValue: '1',
              parentL1Value: 'Seder Zeraim',
            ),
            hebrewTermsScript: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('פרק א'), findsOneWidget);
      });

      testWidgets('Mishnayos Mishnah 1 Hebrew → "משנה א"', (tester) async {
        await tester.pumpWidget(
          wrap(
            const CurriculumLabel.level(
              curriculumId: CurriculumId.mishnayos,
              level: 4,
              rawValue: '1',
              parentL1Value: 'Seder Zeraim',
            ),
            hebrewTermsScript: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('משנה א'), findsOneWidget);
      });

      testWidgets('Mishnayos Perek 1 English → "Perek 1"', (tester) async {
        await tester.pumpWidget(
          wrap(
            const CurriculumLabel.level(
              curriculumId: CurriculumId.mishnayos,
              level: 3,
              rawValue: '1',
              parentL1Value: 'Seder Zeraim',
            ),
            hebrewTermsScript: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Perek 1'), findsOneWidget);
      });
    },
  );

  group('CurriculumLabel.level — named levels (strips structural prefix)', () {
    testWidgets('Mishnayos masechta Hebrew "מסכת ברכות" → "ברכות"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.level(
            curriculumId: CurriculumId.mishnayos,
            level: 2,
            rawValue: 'Berakhot',
            hebrewName: 'מסכת ברכות',
            parentL1Value: 'Seder Zeraim',
          ),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ברכות'), findsOneWidget);
    });

    testWidgets('Mishnayos seder Hebrew → "זרעים"', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.level(
            curriculumId: CurriculumId.mishnayos,
            level: 1,
            rawValue: 'Seder Zeraim',
            hebrewName: 'סדר זרעים',
          ),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('זרעים'), findsOneWidget);
    });
  });

  group('CurriculumLabel.item — leaf mode', () {
    testWidgets('Mishnayos leaf Hebrew → last segment "משנה א"', (
      tester,
    ) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
        displayNameHe: 'משנה ברכות א:א',
        displayNameEn: 'Mishnah Berakhot 1:1',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 0,
        isLeaf: true,
      );
      await tester.pumpWidget(
        wrap(const CurriculumLabel.item(item), hebrewTermsScript: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('משנה א'), findsOneWidget);
    });
  });

  group('CurriculumLabel.item — breadcrumb/parent modes resolve ancestor '
      'Hebrew names (AUD-core-labels-01)', () {
    // Mishnayos has 2 named ancestor levels (Seder, Masechta) above the
    // ordinal Perek/Mishna levels — exactly the shape that exposed the
    // bug (ancestor levels rendered from raw storage-key values, not
    // their Hebrew names).
    const sederItem = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      displayNameHe: 'סדר זרעים',
      displayNameEn: 'Seder Zeraim',
      sefariaRef: 'Seder_Zeraim',
      sortOrder: 0,
      isLeaf: false,
    );
    const masechtaItem = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berakhot',
      displayNameHe: 'מסכת ברכות',
      displayNameEn: 'Mishnah Berakhot',
      sefariaRef: 'Mishnah_Berakhot',
      sortOrder: 1,
      isLeaf: false,
    );
    const perekItem = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berakhot',
      level3: '1',
      displayNameHe: 'משנה ברכות א',
      displayNameEn: 'Mishnah Berakhot 1',
      sefariaRef: 'Mishnah_Berakhot.1',
      sortOrder: 2,
      isLeaf: false,
    );
    const leafItem = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berakhot',
      level3: '1',
      level4: '1',
      displayNameHe: 'משנה ברכות א:א',
      displayNameEn: 'Mishnah Berakhot 1:1',
      sefariaRef: 'Mishnah_Berakhot.1.1',
      sortOrder: 3,
      isLeaf: true,
    );
    final allItems = [sederItem, masechtaItem, perekItem, leafItem];

    // Backs the async ancestor-Hebrew-name lookup
    // (renderedDisplayForRef/renderedParentForRef) with an in-memory
    // fixture instead of the real bundled content DB.
    List<Override> contentOverrides() => [
      curriculumContentProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) async => allItems),
      contentIndexProvider.overrideWith(
        (ref) async =>
            ContentIndex.fromCurricula({CurriculumId.mishnayos: allItems}),
      ),
    ];

    testWidgets('breadcrumb mode: every segment renders Hebrew, no raw Latin '
        'ancestor names', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.item(
            leafItem,
            mode: CurriculumLabelMode.breadcrumb,
          ),
          hebrewTermsScript: true,
          overrides: contentOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      const expected = 'זרעים › ברכות › פרק א › משנה א';
      expect(
        RegExp('[A-Za-z]').hasMatch(expected),
        isFalse,
        reason: 'sanity-check the expected fixture is pure Hebrew',
      );
      expect(find.text(expected), findsOneWidget);
      // The bug rendered ancestor segments from the raw storage key —
      // guard explicitly against that regression.
      expect(find.textContaining('Seder Zeraim'), findsNothing);
      expect(find.textContaining('Berakhot'), findsNothing);
    });

    testWidgets('parent mode: named ancestor segment renders Hebrew, not raw '
        '"Berakhot"', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.item(
            perekItem,
            mode: CurriculumLabelMode.parent,
          ),
          hebrewTermsScript: true,
          overrides: contentOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ברכות'), findsOneWidget);
      expect(find.text('Berakhot'), findsNothing);
    });
  });

  group('curriculumLabelText (pure string helper)', () {
    testWidgets('returns Hebrew when toggle on', (tester) async {
      String? captured;
      await tester.pumpWidget(
        wrap(
          Consumer(
            builder: (context, ref, _) {
              captured = curriculumLabelText(
                ref,
                curriculum: CurriculumId.mishnayos,
              );
              return const SizedBox.shrink();
            },
          ),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, 'משניות');
    });

    testWidgets('returns English Ashkenazi when toggle off', (tester) async {
      String? captured;
      await tester.pumpWidget(
        wrap(
          Consumer(
            builder: (context, ref, _) {
              captured = curriculumLabelText(
                ref,
                curriculum: CurriculumId.mishnayos,
              );
              return const SizedBox.shrink();
            },
          ),
          hebrewTermsScript: false,
          variant: TransliterationVariant.ashkenazi,
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, 'Mishnayos');
    });

    testWidgets('returns English Sephardi form when variant is sephardi', (
      tester,
    ) async {
      String? captured;
      await tester.pumpWidget(
        wrap(
          Consumer(
            builder: (context, ref, _) {
              captured = curriculumLabelText(
                ref,
                curriculum: CurriculumId.mishnayos,
              );
              return const SizedBox.shrink();
            },
          ),
          hebrewTermsScript: false,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, 'Mishnayot');
    });

    testWidgets('Hebrew toggle wins over Sephardi variant', (tester) async {
      String? captured;
      await tester.pumpWidget(
        wrap(
          Consumer(
            builder: (context, ref, _) {
              captured = curriculumLabelText(
                ref,
                curriculum: CurriculumId.mishnayos,
              );
              return const SizedBox.shrink();
            },
          ),
          hebrewTermsScript: true,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, 'משניות');
    });
  });

  group('curriculumLabelFor (ref-free string helper)', () {
    test('Ashkenazi (default variant) → "Mishnayos"', () {
      expect(
        curriculumLabelFor(CurriculumId.mishnayos, useHebrewTerms: false),
        'Mishnayos',
      );
    });

    test('Sephardi variant → "Mishnayot"', () {
      expect(
        curriculumLabelFor(
          CurriculumId.mishnayos,
          useHebrewTerms: false,
          variant: TransliterationVariant.sephardi,
        ),
        'Mishnayot',
      );
    });

    test('Hebrew terms → Hebrew form regardless of variant', () {
      expect(
        curriculumLabelFor(
          CurriculumId.mishnayos,
          useHebrewTerms: true,
          variant: TransliterationVariant.sephardi,
        ),
        'משניות',
      );
    });
  });

  group('curriculumHebrewName (dual-language escape hatch)', () {
    test('always returns Hebrew form regardless of toggle', () {
      expect(curriculumHebrewName(CurriculumId.mishnayos), 'משניות');
      expect(curriculumHebrewName(CurriculumId.bavli), isNotEmpty);
    });
  });

  group('CurriculumLabel.isHebrewText (AUD-tracks-18 canonical detector)', () {
    // Exposed so other Hebrew-aware widgets (e.g.
    // TrackLearningOrderScreen's section headers) can share this single
    // Unicode-range detector instead of hand-rolling a private RegExp copy.
    test('Hebrew-script text is detected', () {
      expect(CurriculumLabel.isHebrewText('משניות'), isTrue);
    });

    test('English-only text is not detected', () {
      expect(CurriculumLabel.isHebrewText('Mishnayos'), isFalse);
    });

    test('mixed Hebrew + English text is detected', () {
      expect(CurriculumLabel.isHebrewText('Seder משניות'), isTrue);
    });

    test('empty string is not detected', () {
      expect(CurriculumLabel.isHebrewText(''), isFalse);
    });
  });
}
