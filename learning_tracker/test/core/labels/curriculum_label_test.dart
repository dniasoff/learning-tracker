import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget wrap(Widget child, {bool hebrewTermsScript = true}) {
    SharedPreferences.setMockInitialValues({
      'hebrew_terms_script_p0': hebrewTermsScript,
    });
    return ProviderScope(
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

    testWidgets('Hebrew terms OFF → displayNameEn', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CurriculumLabel.curriculum(CurriculumId.mishnayos),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('משניות'), findsNothing);
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

    testWidgets('returns English when toggle off', (tester) async {
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
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, 'Mishnayos');
    });
  });

  group('curriculumHebrewName (dual-language escape hatch)', () {
    test('always returns Hebrew form regardless of toggle', () {
      expect(curriculumHebrewName(CurriculumId.mishnayos), 'משניות');
      expect(curriculumHebrewName(CurriculumId.bavli), isNotEmpty);
    });
  });
}
