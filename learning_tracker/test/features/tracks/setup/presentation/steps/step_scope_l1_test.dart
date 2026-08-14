// L1 widget-behaviour tests — ScopeStepContent + ScopeTopLevelView + ScopeHierarchyView
// (lib/features/tracks/setup/presentation/steps/step_scope.dart + scope_views.dart)
//
// Coverage focus (~0% baseline):
//   1. Loading state — CircularProgressIndicator while provider is loading.
//   2. Empty items (DNI-202 auto-skip) — onComplete(null) called immediately.
//   3. Error state (DNI-202 auto-skip) — onComplete(null) called immediately.
//   4. Top-level render — "Learn All" hero card + section header present.
//   5. No track-type labels (Personal/Standard/Custom/אישי) anywhere.
//   6. Curriculum badge chip shown at top.
//   7. Done button disabled when nothing selected ("Select at least one").
//   8. Toggle item → Done button enabled + badge shown on tile.
//   9. Select All → all items checked; second tap (deselect all) unchecks them.
//  10. "Learn All" hero tapped → onComplete(null) called.
//  11. Done tapped with a selection → onComplete called with non-null list.
//  12. ScopeHierarchyView: back button + breadcrumb trail rendered.
//  13. ScopeHierarchyView: selection chip shown; delete chip → removes selection.
//  14. Hebrew (he) locale smoke — pumps without error.

@Tags(['tracks', 'scope_step', 'l1'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/scope_views.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_scope.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

// ── Hebrew-terms override ─────────────────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ── Sample content items ──────────────────────────────────────────────────────

/// Minimal Mishnayos content: 2 sedarim, one masechta each.
List<ContentItem> _mishnayosItems() => [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berakhot',
    level3: '1',
    level4: '1',
    displayNameEn: 'Mishnah Berakhot 1:1',
    displayNameHe: 'משנה ברכות א:א',
    sefariaRef: 'Mishnah_Berakhot.1.1',
    sortOrder: 1,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Moed',
    level2: 'Shabbat',
    level3: '1',
    level4: '1',
    displayNameEn: 'Mishnah Shabbat 1:1',
    displayNameHe: 'משנה שבת א:א',
    sefariaRef: 'Mishnah_Shabbat.1.1',
    sortOrder: 100,
    isLeaf: true,
  ),
];

// ── Widget harness ─────────────────────────────────────────────────────────────

Widget _buildScopeStep({
  required List<Override> overrides,
  required ValueChanged<List<ScopeEntry>?> onComplete,
  CurriculumId curriculumId = CurriculumId.mishnayos,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ScopeStepContent(
          curriculumId: curriculumId,
          onComplete: onComplete,
        ),
      ),
    ),
  );
}

List<Override> _overrides({
  required _MockContentRepository contentRepo,
  bool useHebrew = false,
}) {
  return [
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(
      useHebrew ? _HebrewTermsOn.new : _HebrewTermsOff.new,
    ),
  ];
}

// ── Pump helpers ──────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── ScopeHierarchyView standalone harness ─────────────────────────────────────

Widget _buildHierarchyView({
  required List<ContentItem> items,
  List<ScopeEntry> breadcrumbs = const [],
  List<String> breadcrumbLabels = const [],
  List<ScopeEntry> selections = const [],
  Map<String, String> selectionLabels = const {},
  bool allDirectlySelected = false,
  int currentLevel = 2,
  int maxSelectableLevel = 3,
  bool useHebrew = false,
  VoidCallback? onBack,
  VoidCallback? onDone,
  void Function(ScopeEntry)? onRemoveSelection,
  void Function(ContentItem)? onToggle,
  void Function(ContentItem)? onDrill,
  void Function()? onToggleAll,
  void Function()? onClearBreadcrumbs,
  void Function(int)? onTrimBreadcrumbs,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      useHebrewTermsProvider.overrideWith(
        useHebrew ? _HebrewTermsOn.new : _HebrewTermsOff.new,
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ScopeHierarchyView(
          curriculumId: CurriculumId.mishnayos,
          breadcrumbs: breadcrumbs,
          breadcrumbLabels: breadcrumbLabels,
          items: items,
          useHebrew: useHebrew,
          selections: selections,
          selectionLabels: selectionLabels,
          allDirectlySelected: allDirectlySelected,
          currentLevel: currentLevel,
          maxSelectableLevel: maxSelectableLevel,
          labelForLevel: (level) => level == 1 ? 'Seder' : 'Masechta',
          isSelected: (item) => selections.any((s) => s.value == item.level2),
          isDirectlySelected: (item) =>
              selections.any((s) => s.value == item.level2),
          onToggle: onToggle ?? (_) {},
          onDrill: onDrill ?? (_) {},
          onToggleAll: onToggleAll ?? () {},
          onBack: onBack ?? () {},
          onClearBreadcrumbs: onClearBreadcrumbs ?? () {},
          onTrimBreadcrumbs: onTrimBreadcrumbs ?? (_) {},
          onRemoveSelection: onRemoveSelection ?? (_) {},
          onDone: onDone ?? () {},
        ),
      ),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ==========================================================================
  // 1. LOADING STATE
  // ==========================================================================

  group('Loading state', () {
    testWidgets('shows CircularProgressIndicator while content loads', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      // Never-completing future → provider stays in loading state.
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) => Completer<List<ContentItem>>().future);

      List<ScopeEntry>? completed;
      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (r) => completed = r,
        ),
      );
      // Single pump — loading state visible before future resolves.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // onComplete must NOT have been called during loading.
      expect(completed, isNull);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 2. EMPTY ITEMS — DNI-202 AUTO-SKIP
  // ==========================================================================

  group('Empty content — DNI-202 auto-skip', () {
    testWidgets(
      'empty item list calls onComplete(null) via postFrameCallback',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
        ).thenAnswer((_) async => []);

        List<ScopeEntry>? completed;
        var completedCalled = false;
        await tester.pumpWidget(
          _buildScopeStep(
            overrides: _overrides(contentRepo: contentRepo),
            onComplete: (r) {
              completedCalled = true;
              completed = r;
            },
          ),
        );
        await _settle(tester);

        expect(
          completedCalled,
          isTrue,
          reason: 'Auto-skip must fire for empty content',
        );
        expect(completed, isNull, reason: 'Auto-skip passes null (learn all)');

        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 3. ERROR STATE — DNI-202 AUTO-SKIP
  // ==========================================================================

  group('Error state — DNI-202 auto-skip', () {
    testWidgets('content error calls onComplete(null) via postFrameCallback', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => throw Exception('network error'));

      var completedCalled = false;
      List<ScopeEntry>? completed;
      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (r) {
            completedCalled = true;
            completed = r;
          },
        ),
      );
      await _settle(tester);

      expect(completedCalled, isTrue, reason: 'Auto-skip must fire on error');
      expect(completed, isNull);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 4. TOP-LEVEL RENDER — hero + header
  // ==========================================================================

  group('Top-level render', () {
    testWidgets('"Learn All" hero card and scope title present', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      // Scope step title.
      expect(
        find.textContaining('All of it, or just a section?'),
        findsOneWidget,
      );
      // "Learn All" hero.
      expect(find.text('I want to learn everything!'), findsOneWidget);

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('item tiles rendered for each top-level group', (tester) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      // Two sedarim → two tiles. Each tile is a ScopeLevelTile containing
      // unique text from the rendered seder names.
      // At level 1 the grouping renders Seder Zeraim and Seder Moed.
      expect(find.textContaining('Zeraim'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Moed'), findsAtLeastNWidgets(1));

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 5. NO TRACK-TYPE LABELS (product rule)
  // ==========================================================================

  group('No track-type labels', () {
    testWidgets('scope step shows no Personal/Standard/Custom/אישי labels', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 6. CURRICULUM BADGE CHIP
  // ==========================================================================

  group('Curriculum badge chip', () {
    testWidgets('shows curriculum name chip at the top (Mishnayos)', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      // CurriculumLabel.curriculum renders 'Mishnayos' in English mode.
      expect(find.text('Mishnayos'), findsAtLeastNWidgets(1));

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 7. DONE BUTTON DISABLED WHEN NOTHING SELECTED
  // ==========================================================================

  group('Done button disabled when nothing selected', () {
    testWidgets('Continue button disabled with "Select at least one" label', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      // Find the FilledButton with "Select at least one" text.
      expect(find.text('Select at least one'), findsOneWidget);

      // The FilledButton onPressed must be null (disabled).
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Select at least one'),
      );
      expect(btn.onPressed, isNull);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 8. TOGGLE ITEM → DONE BUTTON ENABLED + BADGE SHOWN
  // ==========================================================================

  group('Toggle item selection', () {
    testWidgets('tapping a tile selects it and enables the Done button', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      // Tap the checkbox in the first scope tile (Seder Zeraim).
      // ScopeLevelTile has checkboxes; find the first Checkbox and tap it.
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsAtLeastNWidgets(1));
      await tester.tap(checkboxes.first);
      await tester.pump();

      // Done button should be enabled now (onPressed != null).
      // The button text changes to 'Continue with 1 selected' or similar.
      final btns = tester.widgetList<FilledButton>(find.byType(FilledButton));
      final doneBtn = btns.lastWhere(
        (b) =>
            b.child is Text &&
            ((b.child as Text).data?.contains('Continue') ?? false),
        orElse: () => btns.first,
      );
      expect(doneBtn.onPressed, isNotNull);

      // SELECTED badge should appear on the selected tile.
      expect(find.text('SELECTED'), findsAtLeastNWidgets(1));

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('tapping same tile again deselects it and disables Done', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      final checkboxes = find.byType(Checkbox);
      // Select.
      await tester.tap(checkboxes.first);
      await tester.pump();
      // Deselect.
      await tester.tap(checkboxes.first);
      await tester.pump();

      // "Select at least one" text back — button disabled.
      expect(find.text('Select at least one'), findsOneWidget);
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Select at least one'),
      );
      expect(btn.onPressed, isNull);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 9. SELECT ALL / DESELECT ALL
  // ==========================================================================

  group('Select All / Deselect All toggle', () {
    testWidgets(
      '"Select all" button selects every item; text becomes "Deselect all"',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
        ).thenAnswer((_) async => _mishnayosItems());

        await tester.pumpWidget(
          _buildScopeStep(
            overrides: _overrides(contentRepo: contentRepo),
            onComplete: (_) {},
          ),
        );
        await _settle(tester);

        expect(find.text('Select all in this list'), findsOneWidget);
        await tester.tap(find.text('Select all in this list'));
        await tester.pump();

        // After selecting all, button text changes to "Deselect all".
        expect(find.text('Deselect all in this list'), findsOneWidget);
        // Both items should show the SELECTED badge.
        expect(find.text('SELECTED'), findsNWidgets(2));

        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      '"Deselect all" after "Select all" unchecks everything and disables Done',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
        ).thenAnswer((_) async => _mishnayosItems());

        await tester.pumpWidget(
          _buildScopeStep(
            overrides: _overrides(contentRepo: contentRepo),
            onComplete: (_) {},
          ),
        );
        await _settle(tester);

        await tester.tap(find.text('Select all in this list'));
        await tester.pump();
        await tester.tap(find.text('Deselect all in this list'));
        await tester.pump();

        expect(find.text('Select all in this list'), findsOneWidget);
        expect(find.text('Select at least one'), findsOneWidget);
        final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Select at least one'),
        );
        expect(btn.onPressed, isNull);

        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 10. "LEARN ALL" HERO TAPPED → onComplete(null)
  // ==========================================================================

  group('"Learn All" hero', () {
    testWidgets(
      'tapping "I want to learn everything!" calls onComplete(null)',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
        ).thenAnswer((_) async => _mishnayosItems());

        List<ScopeEntry>? result;
        var called = false;
        await tester.pumpWidget(
          _buildScopeStep(
            overrides: _overrides(contentRepo: contentRepo),
            onComplete: (r) {
              called = true;
              result = r;
            },
          ),
        );
        await _settle(tester);

        await tester.tap(find.text('I want to learn everything!'));
        await tester.pump();

        expect(called, isTrue);
        expect(result, isNull, reason: 'Learn All passes null to onComplete');

        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 11. DONE WITH SELECTION → onComplete called with non-null list
  // ==========================================================================

  group('Done with a selection', () {
    testWidgets('onComplete receives non-null ScopeEntry list on Done tap', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      List<ScopeEntry>? result;
      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo),
          onComplete: (r) => result = r,
        ),
      );
      await _settle(tester);

      // Select the first item.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Tap the Continue button — finds it by substring so the count suffix
      // ("Continue with 1 selected") doesn't break the match.
      final continueFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('Continue') ?? false),
      );
      expect(continueFinder, findsOneWidget);
      await tester.tap(continueFinder);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.isNotEmpty, isTrue);
      expect(result!.first.level, equals(1));

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 12. ScopeHierarchyView — back button + breadcrumb trail
  // ==========================================================================

  group('ScopeHierarchyView — back button + breadcrumbs', () {
    testWidgets('back button present and calls onBack', (tester) async {
      var backCalled = false;
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['Seder Zeraim'],
          onBack: () => backCalled = true,
        ),
      );
      await _settle(tester);

      // Back arrow button.
      final backBtn = find.byIcon(Icons.arrow_back);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump();

      expect(backCalled, isTrue);

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('breadcrumb label is rendered', (tester) async {
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['Seder Zeraim'],
        ),
      );
      await _settle(tester);

      expect(find.text('Seder Zeraim'), findsAtLeastNWidgets(1));

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Done button disabled when no selections', (tester) async {
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['Seder Zeraim'],
          selections: const [],
        ),
      );
      await _settle(tester);

      expect(find.text('Select at least one'), findsOneWidget);
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Select at least one'),
      );
      expect(btn.onPressed, isNull);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 13. ScopeHierarchyView — selection chip + delete removes selection
  // ==========================================================================

  group('ScopeHierarchyView — selection chips', () {
    testWidgets('selection chip rendered with correct label', (tester) async {
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['Seder Zeraim'],
          selections: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          selectionLabels: {'Seder Zeraim': 'Seder Zeraim'},
          currentLevel: 2,
          maxSelectableLevel: 3,
        ),
      );
      await _settle(tester);

      // The chip label is "Seder: Seder Zeraim" (labelForLevel(1) = 'Seder').
      expect(find.textContaining('Seder Zeraim'), findsAtLeastNWidgets(1));
      expect(find.byType(Chip), findsAtLeastNWidgets(1));

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('deleting a chip calls onRemoveSelection', (tester) async {
      final removed = <ScopeEntry>[];
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['Seder Zeraim'],
          selections: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          selectionLabels: {'Seder Zeraim': 'Seder Zeraim'},
          currentLevel: 2,
          maxSelectableLevel: 3,
          onRemoveSelection: removed.add,
        ),
      );
      await _settle(tester);

      // Tap the delete icon on the chip.
      final deleteIcon = find.byIcon(Icons.close);
      expect(deleteIcon, findsAtLeastNWidgets(1));
      await tester.tap(deleteIcon.first);
      await tester.pump();

      expect(removed, isNotEmpty);
      expect(removed.first.value, equals('Seder Zeraim'));

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Done button enabled when selections are present', (
      tester,
    ) async {
      var doneCalled = false;
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['Seder Zeraim'],
          selections: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          selectionLabels: {'Seder Zeraim': 'Seder Zeraim'},
          currentLevel: 2,
          maxSelectableLevel: 3,
          onDone: () => doneCalled = true,
        ),
      );
      await _settle(tester);

      final doneBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue with 1 selected'),
      );
      expect(doneBtn.onPressed, isNotNull);

      await tester.tap(find.text('Continue with 1 selected'));
      await tester.pump();
      expect(doneCalled, isTrue);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 13b. TOP-LEVEL PROMPT — script-consistent with the Hebrew-Terms toggle
  // ==========================================================================

  group('Top-level prompt — no mixed script under Hebrew Terms', () {
    final hebrew = RegExp('[֐-׿]');
    final latin = RegExp('[A-Za-z]');

    /// Returns the rendered "Choose a {level}" prompt text from the sub-section
    /// breadcrumb header. It is a Text containing the level-1 label.
    String promptText(WidgetTester tester) {
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final d = t.data;
        if (d == null) continue;
        // The top-level prompt is the only string built from
        // scopeChooseLevelPrompt — it contains "Choose"/"בחרו".
        if (d.contains('Choose') || d.contains('בחרו')) return d;
      }
      return '';
    }

    testWidgets('English UI + Terms OFF: prompt is fully English', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo, useHebrew: false),
          onComplete: (_) {},
        ),
      );
      await _settle(tester);

      final prompt = promptText(tester);
      expect(prompt.isNotEmpty, isTrue, reason: 'prompt must render');
      expect(prompt.startsWith('Choose'), isTrue);
      // No Hebrew script leaking into the English-mode prompt.
      expect(hebrew.hasMatch(prompt), isFalse, reason: 'prompt was: $prompt');

      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'English UI + Terms ON: prompt is fully Hebrew (no Latin "Choose a")',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
        ).thenAnswer((_) async => _mishnayosItems());

        await tester.pumpWidget(
          _buildScopeStep(
            // English UI locale, but Hebrew Terms ON — the cross-axis case
            // that previously produced "Choose a סדר" (mixed script).
            overrides: _overrides(contentRepo: contentRepo, useHebrew: true),
            onComplete: (_) {},
          ),
        );
        await _settle(tester);

        final prompt = promptText(tester);
        expect(prompt.isNotEmpty, isTrue, reason: 'prompt must render');
        // Fully Hebrew: starts with "בחרו" and carries NO Latin chrome.
        expect(
          prompt.startsWith('בחרו'),
          isTrue,
          reason: 'prompt was: $prompt',
        );
        expect(
          latin.hasMatch(prompt),
          isFalse,
          reason:
              'Hebrew Terms ON must not leave a Latin "Choose a" wrapping a '
              'Hebrew level word — prompt was: $prompt',
        );

        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 14. HEBREW (he) LOCALE SMOKE TEST
  // ==========================================================================

  group('Hebrew locale smoke test', () {
    testWidgets('ScopeStepContent pumps without error under he locale', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any<CurriculumId>()),
      ).thenAnswer((_) async => _mishnayosItems());

      await tester.pumpWidget(
        _buildScopeStep(
          overrides: _overrides(contentRepo: contentRepo, useHebrew: true),
          onComplete: (_) {},
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      // No exceptions; at minimum the scope title should render.
      expect(tester.takeException(), isNull);
      // The scope title key renders in Hebrew locale (l10n may still be EN
      // if only 'en' is in supportedLocales; just confirm it found a string).
      expect(find.byType(ScopeStepContent), findsOneWidget);

      addTearDown(() => _tearDown(tester));
    });

    testWidgets('ScopeHierarchyView pumps without error under he locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHierarchyView(
          items: _mishnayosItems(),
          breadcrumbs: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          breadcrumbLabels: ['זרעים'],
          selections: [const ScopeEntry(level: 1, value: 'Seder Zeraim')],
          selectionLabels: {'Seder Zeraim': 'זרעים'},
          useHebrew: true,
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);

      addTearDown(() => _tearDown(tester));
    });
  });
}
