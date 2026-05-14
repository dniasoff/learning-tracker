import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_browser_tree.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockContentRepository extends Mock implements ContentRepository {}

/// Container items (sedarim).
const _sederZeraim = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Seder Zeraim',
  displayNameHe: 'סדר זרעים',
  displayNameEn: 'Seder Zeraim',
  sefariaRef: 'Seder Zeraim',
  sortOrder: 0,
  isLeaf: false,
);

const _sederMoed = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Seder Moed',
  displayNameHe: 'סדר מועד',
  displayNameEn: 'Seder Moed',
  sefariaRef: 'Seder Moed',
  sortOrder: 1,
  isLeaf: false,
);

void main() {
  late ContentRepository mockRepo;

  setUp(() {
    // Default Hebrew terms on so labels render in Hebrew.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
    mockRepo = MockContentRepository();
  });

  /// Creates a [ProviderScope] with the content repository mocked and
  /// [contentTreeProvider] forced into an error state (so the widget falls
  /// back to [filteredContentProvider] which is backed by [mockRepo]).
  Widget buildWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        // Force tree to error so the widget falls back to filteredContentProvider.
        contentTreeProvider.overrideWith(
          (ref) async => throw UnimplementedError(),
        ),
        completionCountProvider.overrideWith(
          (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('ContentBrowserTree — none mode', () {
    testWidgets('renders top-level container items', (tester) async {
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => [_sederZeraim, _sederMoed]);

      await tester.pumpWidget(
        buildWidget(
          child: const ContentBrowserTree(
            curriculum: CurriculumId.mishnayos,
            selectionMode: ContentBrowserSelectionMode.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The renderer strips the structural "סדר " prefix for named-level items.
      expect(find.text('זרעים'), findsOneWidget);
      expect(find.text('מועד'), findsOneWidget);
    });

    testWidgets('tapping a container drills down (list changes)', (
      tester,
    ) async {
      // Top level returns two sedarim.
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => [_sederZeraim, _sederMoed]);

      // After drilling into Seder Zeraim, return Berachos.
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer(
        (_) async => [
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berachos',
            sefariaRef: 'Berachos',
            sortOrder: 0,
            isLeaf: false,
          ),
        ],
      );

      await tester.pumpWidget(
        buildWidget(
          child: const ContentBrowserTree(
            curriculum: CurriculumId.mishnayos,
            selectionMode: ContentBrowserSelectionMode.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: two sedarim visible.
      expect(find.text('זרעים'), findsOneWidget);
      expect(find.text('מועד'), findsOneWidget);

      // Tap Seder Zeraim to drill in.
      await tester.tap(find.text('זרעים'));
      await tester.pumpAndSettle();

      // After drill-down: Berachos is shown, sedarim are gone.
      expect(find.text('ברכות'), findsOneWidget);
      expect(find.text('מועד'), findsNothing);
    });
  });

  group('ContentBrowserTree — single mode', () {
    testWidgets('tapping a container drills down', (tester) async {
      Set<HierarchySelection>? emitted;

      // Top level: two sedarim.
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => [_sederZeraim, _sederMoed]);

      // After drilling into Seder Zeraim: return Berachos.
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer(
        (_) async => [
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berachos',
            sefariaRef: 'Berachos',
            sortOrder: 0,
            isLeaf: false,
          ),
        ],
      );

      await tester.pumpWidget(
        buildWidget(
          child: ContentBrowserTree(
            curriculum: CurriculumId.mishnayos,
            selectionMode: ContentBrowserSelectionMode.single,
            onSelectionChanged: (s) => emitted = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially both sedarim visible.
      expect(find.text('זרעים'), findsOneWidget);
      expect(find.text('מועד'), findsOneWidget);

      // Tapping a container drills in (no selection emitted for containers).
      await tester.tap(find.text('זרעים'));
      await tester.pumpAndSettle();

      expect(find.text('ברכות'), findsOneWidget);
      expect(find.text('מועד'), findsNothing);
      // Container taps do not emit a selection.
      expect(emitted, isNull);
    });
  });

  group('ContentBrowserTree — multiCheckbox mode', () {
    testWidgets('checking a container emits selection and shows checkbox', (
      tester,
    ) async {
      Set<HierarchySelection>? emitted;

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => [_sederZeraim, _sederMoed]);

      await tester.pumpWidget(
        buildWidget(
          child: ContentBrowserTree(
            curriculum: CurriculumId.mishnayos,
            selectionMode: ContentBrowserSelectionMode.multiCheckbox,
            onSelectionChanged: (s) => emitted = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both items visible with unchecked checkboxes.
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Tap the first checkbox (Seder Zeraim).
      final firstCheckbox = find.byType(Checkbox).first;
      await tester.tap(firstCheckbox);
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.length, 1);
      // Selection covers Seder Zeraim at level 1.
      expect(emitted!.first, const HierarchySelection(level1: 'Seder Zeraim'));
    });

    testWidgets('initialSelection pre-checks items', (tester) async {
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => [_sederZeraim, _sederMoed]);

      await tester.pumpWidget(
        buildWidget(
          child: ContentBrowserTree(
            curriculum: CurriculumId.mishnayos,
            selectionMode: ContentBrowserSelectionMode.multiCheckbox,
            initialSelection: {
              const HierarchySelection(level1: 'Seder Zeraim'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      final values = checkboxes.map((c) => c.value).toList();
      // First checkbox (Seder Zeraim) should be pre-checked.
      expect(values.first, isTrue);
      // Second checkbox (Seder Moed) should be unchecked.
      expect(values.last, isFalse);
    });

    testWidgets('unchecking a selected item removes it from selection', (
      tester,
    ) async {
      final emitted = <Set<HierarchySelection>>[];

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => [_sederZeraim, _sederMoed]);

      await tester.pumpWidget(
        buildWidget(
          child: ContentBrowserTree(
            curriculum: CurriculumId.mishnayos,
            selectionMode: ContentBrowserSelectionMode.multiCheckbox,
            initialSelection: {
              const HierarchySelection(level1: 'Seder Zeraim'),
            },
            onSelectionChanged: emitted.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the first checkbox to uncheck it.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(emitted, isNotEmpty);
      expect(emitted.last, isEmpty);
    });
  });
}
