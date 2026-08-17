import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget createTestWidget({
    required ContentItem item,
    required VoidCallback onTap,
    int completionCount = 0,
    bool hebrewTermsScript = true,
    bool showReviewBadge = true,
  }) {
    SharedPreferences.setMockInitialValues({
      'hebrew_terms_script_p0': hebrewTermsScript,
    });
    return ProviderScope(
      overrides: [
        // The preference migrated from the retired p0 SharedPreferences
        // bucket to the selected-profile provider; override the provider
        // directly so the widget sees the requested mode.
        useHebrewTermsProvider.overrideWithValue(hebrewTermsScript),
        completionCountProvider(
          curriculumId: item.curriculumId,
          sefariaRef: item.sefariaRef,
        ).overrideWith((ref) async => completionCount),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ContentItemTile(
            item: item,
            curriculum: CurriculumId.mishnayos,
            onTap: onTap,
            showReviewBadge: showReviewBadge,
          ),
        ),
      ),
    );
  }

  group('ContentItemTile', () {
    testWidgets('displays Hebrew name as title', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));
      await tester.pump(); // resolve async completionCountProvider

      // Renderer strips the structural prefix from named-level labels —
      // "סדר זרעים" renders as "זרעים" (the seder is shown bare; the
      // structural "סדר" word is dropped per CurriculumLabelRenderer rules).
      expect(find.text('זרעים'), findsOneWidget);

      // Verify RTL directionality for Hebrew
      final hebrewText = tester.widget<Text>(find.text('זרעים'));
      expect(hebrewText.textDirection, TextDirection.rtl);
      expect(hebrewText.textAlign, TextAlign.start);
    });

    testWidgets(
      'hides English subtitle when Hebrew Terms toggle is on (default)',
      (tester) async {
        const item = ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          displayNameHe: 'סדר זרעים',
          displayNameEn: 'Seder Zeraim',
          sefariaRef: 'Seder Zeraim',
          sortOrder: 0,
          isLeaf: false,
        );

        await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));
        await tester.pump();

        // Hebrew rendered title is shown (stripped to "זרעים").
        expect(find.text('זרעים'), findsOneWidget);
        // English transliteration is suppressed in the default Hebrew-only mode.
        expect(find.text('Seder Zeraim'), findsNothing);
        expect(find.text('Zeraim'), findsNothing);
      },
    );

    testWidgets('shows English title only when Hebrew Terms toggle is off', (
      tester,
    ) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(
        createTestWidget(item: item, onTap: () {}, hebrewTermsScript: false),
      );
      // Wait for the async _load on the notifier to settle.
      await tester.pumpAndSettle();

      // English-only mode: renderer transliterates the rawValue
      // ("Seder Zeraim" — already English so passes through). Hebrew is
      // not displayed as a parallel subtitle.
      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('סדר זרעים'), findsNothing);
      expect(find.text('זרעים'), findsNothing);
    });

    testWidgets('shows folder icon for container items', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));
      await tester.pump();

      expect(find.byIcon(Icons.folder), findsOneWidget);
    });

    testWidgets('shows unchecked icon for leaf items', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berachos',
        level3: 'Perek 1',
        level4: 'Mishna 1',
        displayNameHe: 'משנה א',
        displayNameEn: 'Mishna 1',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 0,
        isLeaf: true,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));
      await tester.pump();

      // Leaf items show completion status icon (unchecked by default)
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('shows chevron for container items', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));
      await tester.pump();

      // Container items show chevron for drill-down
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(
        createTestWidget(item: item, onTap: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    // Chazara product rule regression tests (R4-7):
    // ReviewCountBadge is review-specific and MUST NOT render when
    // showReviewBadge is false (i.e. no chazara track is active).

    testWidgets(
      'hides ReviewCountBadge for leaf item when showReviewBadge is false '
      '(non-chazara track context)',
      (tester) async {
        const item = ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: 'Perek 1',
          level4: 'Mishna 1',
          displayNameHe: 'משנה א',
          displayNameEn: 'Mishna 1',
          sefariaRef: 'Mishnah Berakhot 1.1',
          sortOrder: 0,
          isLeaf: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            item: item,
            onTap: () {},
            completionCount: 3,
            showReviewBadge: false,
          ),
        );
        await tester.pump();

        // Badge text should not appear even though count > 0.
        expect(find.text('3x'), findsNothing);
        expect(find.text('1x'), findsNothing);
      },
    );

    testWidgets(
      'shows ReviewCountBadge for leaf item when showReviewBadge is true '
      '(chazara track context) and count > 0',
      (tester) async {
        const item = ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: 'Perek 1',
          level4: 'Mishna 1',
          displayNameHe: 'משנה א',
          displayNameEn: 'Mishna 1',
          sefariaRef: 'Mishnah Berakhot 1.1',
          sortOrder: 0,
          isLeaf: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            item: item,
            onTap: () {},
            completionCount: 2,
            showReviewBadge: true,
          ),
        );
        await tester.pump();

        // Badge must render when chazara is enabled and count > 0.
        expect(find.text('2x'), findsOneWidget);
      },
    );

    testWidgets('hides ReviewCountBadge for leaf item when count is 0 '
        'regardless of showReviewBadge', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berachos',
        level3: 'Perek 1',
        level4: 'Mishna 1',
        displayNameHe: 'משנה א',
        displayNameEn: 'Mishna 1',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 0,
        isLeaf: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          item: item,
          onTap: () {},
          completionCount: 0,
          showReviewBadge: true,
        ),
      );
      await tester.pump();

      // ReviewCountBadge renders SizedBox.shrink() when count == 0.
      expect(find.text('0x'), findsNothing);
    });
  });

  group('StageCompletionIndicators', () {
    testWidgets('displays completion icons for each stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StageCompletionIndicators(
              stages: {
                1: true, // Complete
                2: false, // Incomplete
                3: true, // Complete
              },
            ),
          ),
        ),
      );

      // Should show 3 icons total
      expect(find.byType(Icon), findsNWidgets(3));

      // 2 should be check_circle (complete)
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

      // 1 should be circle_outlined (incomplete)
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });
  });

  group('AggregateCompletionIndicator', () {
    testWidgets('displays percentage text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 75.5)),
        ),
      );

      // Should show rounded percentage
      expect(find.text('76%'), findsOneWidget);
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 50)),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 0.5); // 50% = 0.5
    });

    testWidgets('handles 0% completion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 0)),
        ),
      );

      expect(find.text('0%'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 0.0);
    });

    testWidgets('handles 100% completion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 100)),
        ),
      );

      expect(find.text('100%'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 1.0);
    });
  });
}
