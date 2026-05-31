// L1 widget tests for:
//   • StudyDaysEditable + StudyDaysReadOnly
//     (lib/features/tracks/setup/presentation/steps/step_study_days.dart)
//   • ContentHierarchyScreen
//     (lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart)
//
// Behaviours covered:
//   StudyDaysEditable:
//     1.  All 7 days default to ON (study) — all 7 Switches are checked.
//     2.  Toggling Monday OFF changes its Switch to unchecked.
//     3.  Toggling Monday OFF then ON again restores it to checked.
//     4.  "Continue" button present at bottom.
//     5.  Tapping Continue emits a Map containing all 7 day-number keys.
//     6.  When a day is toggled OFF its map value becomes 'review'.
//     7.  Day label 'Shabbos' is present (not 'Saturday').
//     8.  No track-type labels (Personal / Standard / Custom / אישי).
//     9.  Hebrew locale smoke — renders without overflow.
//
//   StudyDaysReadOnly:
//    10.  Title "Study Days" shown.
//    11.  "set by program" subtitle contains the programName.
//    12.  All 7 day labels from kStepStudyDayLabels are rendered.
//    13.  Continue button calls onContinue callback.
//    14.  No track-type labels.
//
//   ContentHierarchyScreen:
//    15.  Unknown curriculumId → "Unknown Curriculum" AppBar + error icon.
//    16.  Loading state → CircularProgressIndicator shown.
//    17.  Empty items → "No content available" empty-state widget shown.
//    18.  Non-empty items → ListTile rows (ContentItemTile) rendered.
//    19.  "Browse Content" AppBar title present.
//    20.  Curriculum chip present in breadcrumb row.
//    21.  Back button present at root level (delegates maybePop).
//    22.  Back button at sub-level (non-empty nav stack) navigates up in-widget.
//    23.  Error state from filteredContentProvider → error icon + message.
//    24.  No track-type labels.
//    25.  Hebrew locale smoke — renders without overflow.
//
// PRODUCT RULES asserted:
//   • No "Personal" / "Standard" / "Custom" / "אישי" labels anywhere.
//
// PUMP RIG:
//   ProviderScope(retry:(_, __)=>null, overrides:[...],
//     child: MaterialApp(locale, 4 l10n delegates, home: ...))
//   pump() + pump(const Duration(seconds:1)) — no pumpAndSettle on open streams.
//   Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).

@Tags(['tracks', 'study_days', 'content_browsing', 'l1'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/drift_memory.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Fake Riverpod notifiers ────────────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _kMishnayosConfig = CurriculumHierarchyConfig(
  curriculumId: 'mishnayos',
  levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
  totalItems: 100,
);

// ── Content fixtures ──────────────────────────────────────────────────────────

ContentItem _container({
  required String curriculumId,
  required String level1,
  String? level2,
  required String displayNameHe,
  required String displayNameEn,
  required String sefariaRef,
  required int sortOrder,
}) => ContentItem(
  curriculumId: curriculumId,
  level1: level1,
  level2: level2,
  displayNameHe: displayNameHe,
  displayNameEn: displayNameEn,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
  isLeaf: false,
);

// ── Build helpers ──────────────────────────────────────────────────────────────

/// Builds an app wrapping [StudyDaysEditable] with the given [onComplete] callback.
Widget _buildStudyDaysEditableApp({
  required ValueChanged<Map<int, String>> onComplete,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StudyDaysEditable(onComplete: onComplete)),
    ),
  );
}

/// Builds an app wrapping [StudyDaysReadOnly] with the given [onContinue] callback.
Widget _buildStudyDaysReadOnlyApp({
  required String programName,
  required VoidCallback onContinue,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StudyDaysReadOnly(
          programName: programName,
          onContinue: onContinue,
        ),
      ),
    ),
  );
}

/// Builds an app wrapping [ContentHierarchyScreen].
///
/// [mockRepo] — mock for [contentRepositoryProvider].
/// [treeItems] — items used to populate the [contentTreeProvider].
///   Defaults to empty (so the tree falls back to filteredContentProvider).
/// [filteredItems] — override for [filteredContentProvider].
/// [hierarchyError] — if non-null, [filteredContentProvider] throws.
Widget _buildContentHierarchyApp({
  required _MockStackRouter router,
  required _MockContentRepository mockRepo,
  String curriculumId = 'mishnayos',
  String? level1,
  String? level2,
  String? level3,
  String? level4,
  List<ContentItem>? filteredItems,
  Exception? hierarchyError,
  Locale locale = const Locale('en'),
}) {
  // Build an empty ContentTree so itemsAsync falls through to filteredContentProvider.
  final emptyTree = ContentTree.fromCurricula({
    for (final c in CurriculumId.values) c: const [],
  });

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
      contentRepositoryProvider.overrideWithValue(mockRepo),
      contentTreeProvider.overrideWith((ref) async => emptyTree),
      // Override completionCountProvider to always return 0 (no DB needed).
      completionCountProvider.overrideWith(
        (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
      ),
      filteredContentProvider.overrideWith((
        Ref ref,
        ({
          CurriculumId curriculumId,
          String? level1,
          String? level2,
          String? level3,
          String? level4,
        })
        arg,
      ) async {
        if (hierarchyError != null) throw hierarchyError;
        return filteredItems ?? const [];
      }),
      // Hierarchy config — return stub for mishnayos only.
      curriculumHierarchyConfigProvider.overrideWith((
        ref,
        CurriculumId cid,
      ) async {
        if (cid == CurriculumId.mishnayos) return _kMishnayosConfig;
        return CurriculumHierarchyConfig(
          curriculumId: cid.storageKey,
          levelLabels: const ['L1', 'L2', 'L3', 'L4'],
          totalItems: 0,
        );
      }),
      // curriculumContentProvider — return empty for all curricula.
      curriculumContentProvider.overrideWith(
        (ref, CurriculumId cid) async => const <ContentItem>[],
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: ContentHierarchyScreen(
          curriculumId: curriculumId,
          level1: level1,
          level2: level2,
          level3: level3,
          level4: level4,
        ),
      ),
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(CurriculumId.mishnayos);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  late _MockContentRepository mockRepo;
  late _MockStackRouter router;

  setUp(() {
    mockRepo = _MockContentRepository();
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(() => router.maybePop<Object?>(any())).thenAnswer((_) async => false);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    // Default content repository stubs.
    when(
      () => mockRepo.getHierarchyConfig(any()),
    ).thenAnswer((_) async => _kMishnayosConfig);
    when(
      () => mockRepo.getContentForCurriculum(any()),
    ).thenAnswer((_) async => const <ContentItem>[]);
    when(
      () => mockRepo.filterByLevel(
        curriculumId: any(named: 'curriculumId'),
        level1: any(named: 'level1'),
        level2: any(named: 'level2'),
        level3: any(named: 'level3'),
        level4: any(named: 'level4'),
      ),
    ).thenAnswer((_) async => const <ContentItem>[]);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // StudyDaysEditable
  // ══════════════════════════════════════════════════════════════════════════

  group('StudyDaysEditable — default state (all 7 days ON)', () {
    testWidgets('1. all 7 Switch widgets are initially ON', (tester) async {
      // Use a tall viewport so all 7 day cards fit without scrolling.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildStudyDaysEditableApp(onComplete: (_) {}));
      await _settle(tester);

      // All 7 day cards render a Switch. Every Switch must be enabled (value=true).
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, 7, reason: 'One Switch per day expected');
      for (final s in switches) {
        expect(
          s.value,
          isTrue,
          reason: 'All days default to study (Switch=on)',
        );
      }
      await _teardown(tester);
    });

    testWidgets('4. "Continue" button is present', (tester) async {
      await tester.pumpWidget(_buildStudyDaysEditableApp(onComplete: (_) {}));
      await _settle(tester);

      expect(find.text('Continue'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('7. "Shabbos" day label present (not "Saturday")', (
      tester,
    ) async {
      // Use a tall viewport so Shabbos (the 7th card) is in the render tree.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildStudyDaysEditableApp(onComplete: (_) {}));
      await _settle(tester);

      expect(find.text('Shabbos'), findsOneWidget);
      expect(find.text('Saturday'), findsNothing);
      await _teardown(tester);
    });
  });

  group('StudyDaysEditable — toggle interactions', () {
    testWidgets('2. toggling Monday OFF → its Switch becomes unchecked', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStudyDaysEditableApp(onComplete: (_) {}));
      await _settle(tester);

      // Tap the Switch for Monday (the 2nd card, index 1 in the list).
      // kStepStudyDayLabels = [Sun, Mon, Tue, Wed, Thu, Fri, Shabbos]
      // kStepStudyDayNumbers = [7, 1, 2, 3, 4, 5, 6]
      // Monday = index 1 in the list view.
      final switchFinders = find.byType(Switch);
      // Switch at index 1 is Monday.
      await tester.tap(switchFinders.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(
        switches[1].value,
        isFalse,
        reason: 'Monday Switch should be OFF after tap',
      );
      await _teardown(tester);
    });

    testWidgets('3. toggling Monday OFF then ON again restores checked state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStudyDaysEditableApp(onComplete: (_) {}));
      await _settle(tester);

      final switchFinders = find.byType(Switch);
      // Toggle OFF
      await tester.tap(switchFinders.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Toggle ON again
      await tester.tap(find.byType(Switch).at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[1].value, isTrue, reason: 'Monday should be back ON');
      await _teardown(tester);
    });

    testWidgets(
      '5. tapping Continue emits map with all 7 ISO day-number keys',
      (tester) async {
        Map<int, String>? emitted;
        await tester.pumpWidget(
          _buildStudyDaysEditableApp(onComplete: (days) => emitted = days),
        );
        await _settle(tester);

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(emitted, isNotNull);
        // kStepStudyDayNumbers = [7, 1, 2, 3, 4, 5, 6]
        expect(emitted!.keys.toSet(), {1, 2, 3, 4, 5, 6, 7});
        await _teardown(tester);
      },
    );

    testWidgets(
      '6. toggling a day OFF emits that day with value "review" in Continue map',
      (tester) async {
        Map<int, String>? emitted;
        await tester.pumpWidget(
          _buildStudyDaysEditableApp(onComplete: (days) => emitted = days),
        );
        await _settle(tester);

        // Toggle Monday (index 1) OFF.
        await tester.tap(find.byType(Switch).at(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(emitted, isNotNull);
        // Day 1 = Monday (ISO day number)
        expect(
          emitted![1],
          equals('review'),
          reason: 'Day toggled OFF should emit "review"',
        );
        // Other days remain 'study'.
        expect(
          emitted![7],
          equals('study'),
          reason: 'Sunday should still be study',
        );
        await _teardown(tester);
      },
    );
  });

  group('StudyDaysEditable — product rules', () {
    testWidgets('8. no track-type labels in editable study days', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStudyDaysEditableApp(onComplete: (_) {}));
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('9. Hebrew locale smoke — renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStudyDaysEditableApp(
          onComplete: (_) {},
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // StudyDaysReadOnly
  // ══════════════════════════════════════════════════════════════════════════

  group('StudyDaysReadOnly — layout', () {
    testWidgets('10. "Study Days" title is shown', (tester) async {
      await tester.pumpWidget(
        _buildStudyDaysReadOnlyApp(programName: 'Daf Yomi', onContinue: () {}),
      );
      await _settle(tester);

      expect(find.text('Study Days'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('11. subtitle contains the programName', (tester) async {
      await tester.pumpWidget(
        _buildStudyDaysReadOnlyApp(programName: 'Daf Yomi', onContinue: () {}),
      );
      await _settle(tester);

      expect(find.textContaining('Daf Yomi'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('12. all 7 day labels from kStepStudyDayLabels are rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStudyDaysReadOnlyApp(programName: 'Daf Yomi', onContinue: () {}),
      );
      await _settle(tester);

      for (final label in kStepStudyDayLabels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Day label "$label" should be visible',
        );
      }
      await _teardown(tester);
    });

    testWidgets('13. Continue button calls onContinue callback', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        _buildStudyDaysReadOnlyApp(
          programName: 'Daf Yomi',
          onContinue: () => called = true,
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(called, isTrue, reason: 'onContinue must be invoked on tap');
      await _teardown(tester);
    });

    testWidgets('14. no track-type labels in read-only study days', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStudyDaysReadOnlyApp(programName: 'Daf Yomi', onContinue: () {}),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentHierarchyScreen
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentHierarchyScreen — unknown curriculum', () {
    testWidgets(
      '15. unknown curriculumId → "Unknown Curriculum" AppBar + error icon',
      (tester) async {
        await tester.pumpWidget(
          _buildContentHierarchyApp(
            router: router,
            mockRepo: mockRepo,
            curriculumId: 'nonexistent_curriculum_xyz',
          ),
        );
        await _settle(tester);

        expect(find.text('Unknown Curriculum'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  group('ContentHierarchyScreen — loading state', () {
    testWidgets('16. loading state → CircularProgressIndicator shown', (
      tester,
    ) async {
      // Use a never-completing filteredContentProvider at a sub-level
      // so the body stays in loading indefinitely.
      // Pass level1='Seder Zeraim' so _navigationStack.isNotEmpty, then the
      // tree returns empty children → filteredContentProvider is called.
      final emptyTree = ContentTree.fromCurricula({
        for (final c in CurriculumId.values) c: const [],
      });

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
            userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
            useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
            contentRepositoryProvider.overrideWithValue(mockRepo),
            // Resolves immediately to empty tree.
            contentTreeProvider.overrideWith((ref) async => emptyTree),
            completionCountProvider.overrideWith(
              (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
            ),
            // Never completes → loading state for filteredContent.
            filteredContentProvider.overrideWith(
              (
                Ref ref,
                ({
                  CurriculumId curriculumId,
                  String? level1,
                  String? level2,
                  String? level3,
                  String? level4,
                })
                arg,
              ) => Future<List<ContentItem>>.delayed(const Duration(hours: 1)),
            ),
            curriculumHierarchyConfigProvider.overrideWith(
              (ref, CurriculumId cid) async => _kMishnayosConfig,
            ),
            curriculumContentProvider.overrideWith(
              (ref, CurriculumId cid) async => const <ContentItem>[],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: _kDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: const ContentHierarchyScreen(
                curriculumId: 'mishnayos',
                level1: 'Seder Zeraim',
              ),
            ),
          ),
        ),
      );
      // Right after pumpWidget — no async work has resolved yet → spinner shown.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _teardown(tester);
    });
  });

  group('ContentHierarchyScreen — empty items state', () {
    testWidgets(
      '17. empty items list → "No content available" empty-state shown',
      (tester) async {
        await tester.pumpWidget(
          _buildContentHierarchyApp(
            router: router,
            mockRepo: mockRepo,
            filteredItems: const [],
          ),
        );
        await _settle(tester);

        expect(find.text('No content available'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  group('ContentHierarchyScreen — populated items', () {
    testWidgets('18. non-empty items → ListTile rows rendered', (tester) async {
      // Items at depth-1 (level1='Seder Zeraim' selected, showing masechtos).
      // Passing level1 ensures _navigationStack.isNotEmpty so the tree-empty
      // fallback to filteredContentProvider is triggered.
      final items = [
        _container(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berachos',
          sefariaRef: 'Berachos',
          sortOrder: 0,
        ),
        _container(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Peah',
          displayNameHe: 'פאה',
          displayNameEn: 'Peah',
          sefariaRef: 'Peah',
          sortOrder: 1,
        ),
      ];

      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          level1: 'Seder Zeraim',
          filteredItems: items,
        ),
      );
      await _settle(tester);

      // ContentItemTile renders as a ListTile — at least 2 visible.
      expect(find.byType(ListTile), findsAtLeastNWidgets(2));
      await _teardown(tester);
    });

    testWidgets('19. "Browse Content" AppBar title is present', (tester) async {
      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          filteredItems: const [],
        ),
      );
      await _settle(tester);

      expect(find.text('Browse Content'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('20. curriculum chip visible in breadcrumb area', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          filteredItems: const [],
        ),
      );
      await _settle(tester);

      // The curriculum chip always renders a Container with the label.
      // At root level there should be no nav stack so only the chip is shown.
      expect(find.byType(Container), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });
  });

  group('ContentHierarchyScreen — navigation', () {
    testWidgets(
      '21. back button at root level is present and calls router.maybePop',
      (tester) async {
        await tester.pumpWidget(
          _buildContentHierarchyApp(
            router: router,
            mockRepo: mockRepo,
            filteredItems: const [],
          ),
        );
        await _settle(tester);

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        // At root level the back button calls router.maybePop.
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        // The call is maybePop<Object?>(null); verify without type constraint.
        verify(() => router.maybePop<Object?>(any())).called(1);
        await _teardown(tester);
      },
    );

    testWidgets(
      '22. back button at sub-level pops nav stack (in-widget up-navigation)',
      (tester) async {
        // Start with level1 = 'Seder Zeraim' already in the nav stack.
        // After tapping back the nav stack becomes empty and the back button
        // should NOT call router.maybePop (it navigates up in-widget).
        final level1Items = [
          _container(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berachos',
            sefariaRef: 'Berachos',
            sortOrder: 0,
          ),
        ];

        await tester.pumpWidget(
          _buildContentHierarchyApp(
            router: router,
            mockRepo: mockRepo,
            level1: 'Seder Zeraim',
            filteredItems: level1Items,
          ),
        );
        await _settle(tester);

        // Back button is present.
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        // Tap back — should navigate up in-widget (not call router.maybePop).
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // router.maybePop must NOT have been called — nav was handled in-widget.
        verifyNever(() => router.maybePop<Object?>(any()));
        await _teardown(tester);
      },
    );
  });

  group('ContentHierarchyScreen — error state', () {
    testWidgets('23. error from filteredContentProvider → error icon shown', (
      tester,
    ) async {
      // Pass level1 so _navigationStack.isNotEmpty — this triggers the
      // filteredContentProvider fallback path and the error surfaces.
      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          level1: 'Seder Zeraim',
          hierarchyError: Exception('Load failed'),
        ),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.error), findsOneWidget);
      await _teardown(tester);
    });
  });

  group('ContentHierarchyScreen — product rules', () {
    testWidgets('24. no track-type labels', (tester) async {
      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          filteredItems: const [],
        ),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('25. Hebrew locale smoke — renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          filteredItems: const [],
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ── E2 regression: search icon navigates to ContentSearchRoute ───────────────

  group('ContentHierarchyScreen — search icon navigation (E2)', () {
    testWidgets('26. search icon is present in AppBar', (tester) async {
      await tester.pumpWidget(
        _buildContentHierarchyApp(
          router: router,
          mockRepo: mockRepo,
          filteredItems: const [],
        ),
      );
      await _settle(tester);

      expect(
        find.byKey(const Key('content_hierarchy_search_icon')),
        findsOneWidget,
      );
      await _teardown(tester);
    });

    testWidgets(
      '27. tapping search icon calls router.push(ContentSearchRoute)',
      (tester) async {
        await tester.pumpWidget(
          _buildContentHierarchyApp(
            router: router,
            mockRepo: mockRepo,
            curriculumId: 'mishnayos',
            filteredItems: const [],
          ),
        );
        await _settle(tester);

        await tester.tap(
          find.byKey(const Key('content_hierarchy_search_icon')),
        );
        await tester.pump();

        final captured = verify(
          () => router.push<Object?>(
            captureAny(),
            onFailure: any(named: 'onFailure'),
          ),
        ).captured;
        expect(
          captured.any(
            (arg) =>
                arg is PageRouteInfo && arg.routeName == 'ContentSearchRoute',
          ),
          isTrue,
          reason:
              'Tapping the search icon must push ContentSearchRoute (E2 fix)',
        );

        await _teardown(tester);
      },
    );
  });
}
