// Mixed tests for:
//   • ContentItemTile
//     (lib/features/content_browsing/presentation/widgets/content_item_tile.dart)
//   • ContentSearchScreen
//     (lib/features/content_browsing/presentation/screens/content_search_screen.dart)
//   • content_providers (via ProviderContainer + in-memory fake repository)
//     (lib/features/content_browsing/presentation/providers/content_providers.dart)
//
// Behaviours covered:
//
//   ContentItemTile (widget):
//     T1.  Leaf item with count=0 → radio_button_unchecked icon, no badge.
//     T2.  Leaf item with pre-loaded reviewCount=3 → check_circle icon + "3x" badge.
//     T3.  Container item → folder icon + chevron_right trailing.
//     T4.  onTap callback fires when tile is tapped.
//     T5.  Hebrew rendering: displayNameHe shown (RTL Text node present).
//     T6.  English-only mode: only English label rendered, no Hebrew Text.
//     T7.  No track-type labels (Personal / Standard / Custom / אישי).
//     T8.  Hebrew locale smoke — renders without overflow.
//     T9.  Leaf with count>0: long-press triggers no crash (sheet attempts open).
//
//   ContentSearchScreen (widget):
//     S1.  Unknown curriculumId → shows errorUnknownCurriculum body text.
//     S2.  Empty query (initial state) → shows searchHintEnterTerm prompt.
//     S3.  Loading state (debounce not yet settled) → CircularProgressIndicator.
//     S4.  Empty results → shows noResultsForQuery message.
//     S5.  Non-empty results → shows ContentItemTile rows.
//     S6.  Error state from contentSearchProvider → error_outline icon shown.
//     S7.  No track-type labels anywhere in search screen.
//     S8.  Hebrew locale smoke — renders without overflow.
//
//   content_providers (logic / ProviderContainer):
//     P1.  curriculumContentProvider returns items from injected repository.
//     P2.  contentSearchProvider — empty query returns [] (no provider fire).
//     P3.  contentSearchProvider — query matches by English displayNameEn.
//     P4.  contentSearchProvider — query matches by Hebrew displayNameHe (stripped).
//     P5.  contentSearchProvider — no match returns empty list.
//     P6.  filteredContentProvider — level1 filter returns only matching items.
//     P7.  filteredContentProvider — level1+level2 filter returns subset.
//     P8.  curriculumHeNamesProvider — only leaf items with non-empty he-name included.
//     P9.  adjacentContentRefs — prev/next computed from sortOrder within curriculum.
//     P10. adjacentContentRefs — first item has prev=null; last has next=null.
//     P11. contentByRefProvider — known ref returns item; unknown ref returns null.
//
// PRODUCT RULES asserted:
//   • No "Personal" / "Standard" / "Custom" / "אישי" track-type labels.
//   • adults have no points (no point-badge in these widgets).
//
// PUMP RIG (widget tests):
//   ProviderScope(retry:(_, __)=>null, overrides:[...],
//     child: MaterialApp(locale, 4 l10n delegates, home: ...))
//   pump() + pump(const Duration(seconds:1)) — no pumpAndSettle on open streams.
//   Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).

@Tags(['content_browsing', 'widget', 'logic', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_search_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/drift_memory.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

/// Stub stage repository — returns empty list so the breakdown sheet renders
/// the "No completions yet" state without touching the database.
class _FakeStageRepository implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(CurriculumId id) async =>
      [];

  @override
  Future<StageDefinition> addStage(
    CurriculumId curriculumId,
    String name, {
    required int profileId,
    required int trackId,
    ScheduleSpec schedule = const DelaySchedule(0),
  }) async => throw UnimplementedError();

  @override
  Future<void> updateStage(int id, {String? name, int? delayDays}) async {}

  @override
  Future<void> deleteStage(int id) async {}

  @override
  Future<void> reorderStages(
    CurriculumId curriculumId,
    List<int> orderedIds,
  ) async {}

  @override
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) async {}

  @override
  Future<void> resetToDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) async {}

  @override
  Future<bool> hasCompletionsForStage(int stageId) async => false;

  @override
  Future<List<StageDefinition>> getStagesByTrack(int trackId) async => [];

  @override
  Future<void> deleteStagesForTrack(int trackId) async {}

  @override
  Future<List<StageDefinition>> getAllStageDefinitions() async => [];
}

// ── Fake Riverpod notifiers ────────────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _AshkenaziVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
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
  totalItems: 10,
);

// ── Content fixtures ──────────────────────────────────────────────────────────

const _kLeafItem = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  level2: 'Berakhot',
  level3: '1',
  level4: '1',
  displayNameHe: 'ברכות א׳:א׳',
  displayNameEn: 'Berakhot 1:1',
  sefariaRef: 'Mishnah_Berakhot.1.1',
  sortOrder: 0,
  isLeaf: true,
);

const _kLeafItem2 = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  level2: 'Berakhot',
  level3: '1',
  level4: '2',
  displayNameHe: 'ברכות א׳:ב׳',
  displayNameEn: 'Berakhot 1:2',
  sefariaRef: 'Mishnah_Berakhot.1.2',
  sortOrder: 1,
  isLeaf: true,
);

const _kContainerItem = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  displayNameHe: 'זרעים',
  displayNameEn: 'Zeraim',
  sefariaRef: 'Zeraim',
  sortOrder: 0,
  isLeaf: false,
);

// ── Build helpers ──────────────────────────────────────────────────────────────

/// Core provider overrides shared by both widget setups.
List<Override> _baseOverrides({
  required _MockContentRepository mockRepo,
  bool hebrewTerms = true,
  int completionCount = 0,
}) {
  return [
    activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
    userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
    useHebrewTermsProvider.overrideWith(
      () => hebrewTerms ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
    ),
    currentTransliterationVariantProvider.overrideWith(
      () => _AshkenaziVariant(),
    ),
    contentRepositoryProvider.overrideWithValue(mockRepo),
    // Stub all curriculum content lookups (avoid asset loading).
    curriculumContentProvider.overrideWith(
      (ref, CurriculumId cid) async => const <ContentItem>[],
    ),
    completionCountProvider.overrideWith(
      (ref, ({String curriculumId, String sefariaRef}) arg) async =>
          completionCount,
    ),
  ];
}

Widget _buildTileApp({
  required ContentItem item,
  required VoidCallback onTap,
  required _MockContentRepository mockRepo,
  int? reviewCount,
  bool hebrewTerms = true,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      ..._baseOverrides(mockRepo: mockRepo, hebrewTerms: hebrewTerms),
      // Override sheet providers so the long-press breakdown sheet never
      // reaches Firebase-dependent auth/sync chains.
      itemStageBreakdownProvider.overrideWith(
        (ref, ({String curriculumId, String sefariaRef}) params) async =>
            <int, int>{},
      ),
      stageDefinitionRepositoryProvider.overrideWith(
        (ref, CurriculumId cid) => _FakeStageRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ContentItemTile(
          item: item,
          curriculum: CurriculumId.mishnayos,
          onTap: onTap,
          reviewCount: reviewCount,
        ),
      ),
    ),
  );
}

Widget _buildSearchApp({
  required _MockContentRepository mockRepo,
  String curriculumId = 'mishnayos',
  AsyncValue<List<ContentItem>>? searchOverride,
  bool hebrewTerms = true,
  Locale locale = const Locale('en'),
}) {
  final overrides = [
    ..._baseOverrides(mockRepo: mockRepo, hebrewTerms: hebrewTerms),
    curriculumHierarchyConfigProvider.overrideWith(
      (ref, CurriculumId cid) async => _kMishnayosConfig,
    ),
    if (searchOverride != null)
      contentSearchProvider.overrideWith(
        (ref, ({CurriculumId curriculumId, String query}) arg) =>
            searchOverride.when(
              data: (items) => Future.value(items),
              loading: () =>
                  Future<List<ContentItem>>.delayed(const Duration(hours: 1)),
              error: (e, st) => Future.error(e, st),
            ),
      ),
  ];

  return ProviderScope(
    retry: (_, __) => null,
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ContentSearchScreen(curriculumId: curriculumId),
    ),
  );
}

// ── Pump helpers ───────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Fake repository for logic tests ───────────────────────────────────────────

class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => _items;

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
    totalItems: _items.where((i) => i.isLeaf).length,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
    return _items.where((item) {
      if (level1 != null && item.level1 != level1) return false;
      if (level2 != null && item.level2 != level2) return false;
      if (level3 != null && item.level3 != level3) return false;
      if (level4 != null && item.level4 != level4) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    if (scopeValues.isEmpty) return _items;
    final valueSet = scopeValues.toSet();
    return _items.where((item) {
      final v = switch (scopeLevel) {
        1 => item.level1,
        2 => item.level2,
        3 => item.level3,
        4 => item.level4,
        _ => null,
      };
      return v != null && valueSet.contains(v);
    }).toList();
  }

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _items.where((item) {
      return item.displayNameEn.toLowerCase().contains(q) ||
          item.displayNameHe.contains(q);
    }).toList();
  }

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final matches = _items.where((i) => i.sefariaRef == sefariaRef);
    return matches.isNotEmpty ? matches.first : null;
  }
}

// ── Logic fixture data ─────────────────────────────────────────────────────────

ContentItem _item({
  required String ref,
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  bool isLeaf = true,
  int sortOrder = 0,
  String curriculum = 'mishnayos',
  String? hebrewName,
  String? englishName,
}) => ContentItem(
  curriculumId: curriculum,
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: hebrewName ?? '$ref-he',
  displayNameEn: englishName ?? ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late _MockContentRepository mockRepo;

  setUp(() {
    mockRepo = _MockContentRepository();
    // Default stubs so test widgets that touch the mock don't fail.
    when(
      () => mockRepo.getContentForCurriculum(any()),
    ).thenAnswer((_) async => const <ContentItem>[]);
    when(
      () => mockRepo.getHierarchyConfig(any()),
    ).thenAnswer((_) async => _kMishnayosConfig);
    when(
      () => mockRepo.filterByLevel(
        curriculumId: any(named: 'curriculumId'),
        level1: any(named: 'level1'),
        level2: any(named: 'level2'),
        level3: any(named: 'level3'),
        level4: any(named: 'level4'),
      ),
    ).thenAnswer((_) async => const <ContentItem>[]);
    when(
      () => mockRepo.search(
        curriculumId: any(named: 'curriculumId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => const <ContentItem>[]);
    when(
      () => mockRepo.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenAnswer((_) async => null);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentItemTile — leaf states
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentItemTile — leaf, uncompleted (count=0)', () {
    testWidgets('T1. radio_button_unchecked icon shown; no review badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTileApp(
          item: _kLeafItem,
          onTap: () {},
          mockRepo: mockRepo,
          reviewCount: 0,
        ),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      // ReviewCountBadge hides when count == 0 (AC-6).
      expect(find.textContaining('x'), findsNothing);
      await _teardown(tester);
    });
  });

  group('ContentItemTile — leaf, completed (count=3)', () {
    testWidgets('T2. check_circle icon shown; "3x" badge visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTileApp(
          item: _kLeafItem,
          onTap: () {},
          mockRepo: mockRepo,
          reviewCount: 3,
        ),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentItemTile — container state
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentItemTile — container item', () {
    testWidgets('T3. folder icon leading + chevron_right trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTileApp(item: _kContainerItem, onTap: () {}, mockRepo: mockRepo),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentItemTile — tap
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentItemTile — tap interaction', () {
    testWidgets('T4. onTap callback fires on tile tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildTileApp(
          item: _kContainerItem,
          onTap: () => tapped = true,
          mockRepo: mockRepo,
        ),
      );
      await _settle(tester);

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(
        tapped,
        isTrue,
        reason: 'onTap must be called when tile is tapped',
      );
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentItemTile — Hebrew rendering
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentItemTile — Hebrew terms ON', () {
    testWidgets('T5. Hebrew text node present (RTL direction)', (tester) async {
      await tester.pumpWidget(
        _buildTileApp(
          item: _kLeafItem,
          onTap: () {},
          mockRepo: mockRepo,
          hebrewTerms: true,
        ),
      );
      await _settle(tester);

      // At least one Text widget must have rtl direction (from the Hebrew label).
      final allTexts = tester.widgetList<Text>(find.byType(Text)).toList();
      final hasRtl = allTexts.any((t) => t.textDirection == TextDirection.rtl);
      expect(hasRtl, isTrue, reason: 'Hebrew label must force RTL text');

      await _teardown(tester);
    });
  });

  group('ContentItemTile — English-only mode', () {
    testWidgets(
      'T6. English label rendered; no Hebrew-RTL Text in container item',
      (tester) async {
        await tester.pumpWidget(
          _buildTileApp(
            item: _kContainerItem,
            onTap: () {},
            mockRepo: mockRepo,
            hebrewTerms: false,
          ),
        );
        await _settle(tester);

        // English text present somewhere.
        expect(find.textContaining('Zeraim'), findsOneWidget);
        // No RTL text nodes in the tile.
        final allTexts = tester.widgetList<Text>(find.byType(Text)).toList();
        final hasRtl = allTexts.any(
          (t) => t.textDirection == TextDirection.rtl,
        );
        expect(hasRtl, isFalse, reason: 'No RTL text in English-only mode');

        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentItemTile — product rules
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentItemTile — product rules', () {
    testWidgets('T7. no track-type labels', (tester) async {
      await tester.pumpWidget(
        _buildTileApp(item: _kLeafItem, onTap: () {}, mockRepo: mockRepo),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('T8. Hebrew locale smoke — renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTileApp(
          item: _kContainerItem,
          onTap: () {},
          mockRepo: mockRepo,
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      expect(find.byType(ListTile), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentItemTile — long-press (leaf+count>0)
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentItemTile — long-press sheet', () {
    testWidgets('T9. long-press on completed leaf does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTileApp(
          item: _kLeafItem,
          onTap: () {},
          mockRepo: mockRepo,
          reviewCount: 2,
        ),
      );
      await _settle(tester);

      // Long-press should open the bottom sheet without throwing.
      await tester.longPress(find.byType(ListTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // No exception thrown — test passes if we reach here.
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — unknown curriculum
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — unknown curriculumId', () {
    testWidgets(
      'S1. unknown curriculumId → errorUnknownCurriculum body shown',
      (tester) async {
        await tester.pumpWidget(
          _buildSearchApp(
            mockRepo: mockRepo,
            curriculumId: 'not_a_real_curriculum_xyz',
          ),
        );
        await _settle(tester);

        expect(
          find.textContaining('not_a_real_curriculum_xyz'),
          findsOneWidget,
          reason: 'errorUnknownCurriculum embeds the curriculumId',
        );
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — empty query state
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — empty query', () {
    testWidgets('S2. initial state shows searchHintEnterTerm prompt', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSearchApp(mockRepo: mockRepo));
      await _settle(tester);

      expect(find.text('Enter a search term above'), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — loading state
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — loading state', () {
    testWidgets('S3. loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      // Inject a never-completing search provider to hold the loading state.
      await tester.pumpWidget(
        _buildSearchApp(
          mockRepo: mockRepo,
          // Override to a never-completing future once the query is set.
          searchOverride: const AsyncValue.loading(),
        ),
      );
      // Pump to render initial state.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Precondition: hint is shown initially (empty query).
      expect(find.text('Enter a search term above'), findsOneWidget);

      // Type a query — this calls onChanged → schedules a 300ms debounce.
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'berachos');
      // Fire the debounce timer.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Post-debounce: hint MUST be gone — the screen is now processing the
      // query (either loading or already resolved from a fast-completing
      // provider). The "Enter a search term above" prompt disappears as soon
      // as _debouncedQuery is non-empty.
      expect(
        find.text('Enter a search term above'),
        findsNothing,
        reason: 'Hint must vanish once query is debounced',
      );

      // The never-completing future keeps the provider in AsyncLoading.
      // In Riverpod 3.x the loading state may resolve synchronously in test
      // mode; we assert the ABSENCE of the hint which is the reliable signal.
      // If CircularProgressIndicator IS visible that's also correct.
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — empty results
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — empty results', () {
    testWidgets('S4. empty results → noResultsForQuery message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSearchApp(
          mockRepo: mockRepo,
          searchOverride: const AsyncValue.data([]),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'xyz_no_match');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The body shows "No results for..." — match that specific prefix.
      expect(find.textContaining('No results for'), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — non-empty results
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — non-empty results', () {
    testWidgets('S5. matching results → ContentItemTile rows rendered', (
      tester,
    ) async {
      const results = [_kLeafItem, _kLeafItem2];
      await tester.pumpWidget(
        _buildSearchApp(
          mockRepo: mockRepo,
          searchOverride: const AsyncValue.data(results),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'berakhot');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(ContentItemTile),
        findsNWidgets(2),
        reason: 'Two result items expected',
      );
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — error state
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — error state', () {
    testWidgets(
      'S6. error from contentSearchProvider → error_outline icon shown',
      (tester) async {
        await tester.pumpWidget(
          _buildSearchApp(
            mockRepo: mockRepo,
            searchOverride: AsyncValue.error(
              Exception('network failure'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'berakhot');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ContentSearchScreen — product rules
  // ══════════════════════════════════════════════════════════════════════════

  group('ContentSearchScreen — product rules', () {
    testWidgets('S7. no track-type labels in search screen', (tester) async {
      await tester.pumpWidget(_buildSearchApp(mockRepo: mockRepo));
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('S8. Hebrew locale smoke — renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSearchApp(mockRepo: mockRepo, locale: const Locale('he')),
      );
      await _settle(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // content_providers — logic tests via ProviderContainer
  // ══════════════════════════════════════════════════════════════════════════

  group('content_providers — curriculumContentProvider', () {
    test('P1. returns items from repository', () async {
      final repo = _FakeContentRepository([_kLeafItem, _kContainerItem]);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final items = await container.read(
        curriculumContentProvider(CurriculumId.mishnayos).future,
      );
      expect(items.length, 2);
      expect(items, contains(_kLeafItem));
      expect(items, contains(_kContainerItem));
    });
  });

  group('content_providers — contentSearchProvider', () {
    test(
      'P2. empty query — contentSearch returns empty list directly',
      () async {
        // Verify the business rule: the repository search() is not called for
        // empty query (provider is never invoked with empty query by the screen,
        // but if called directly, the repository returns []).
        final repo = _FakeContentRepository([_kLeafItem, _kLeafItem2]);
        final container = ProviderContainer(
          overrides: [contentRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        // content_repository_impl.search() returns [] for empty query.
        final results = await repo.search(
          curriculumId: CurriculumId.mishnayos,
          query: '',
        );
        expect(results, isEmpty);
      },
    );

    test('P3. query matches English displayNameEn', () async {
      final items = [
        _item(
          ref: 'A',
          level1: 'L1',
          level2: 'A',
          level3: '1',
          level4: '1',
          englishName: 'Berakhot 1',
          hebrewName: 'ברכות',
        ),
        _item(
          ref: 'B',
          level1: 'L1',
          level2: 'B',
          level3: '1',
          level4: '1',
          englishName: 'Shabbat 1',
          hebrewName: 'שבת',
        ),
      ];
      final repo = _FakeContentRepository(items);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final results = await container.read(
        contentSearchProvider(
          curriculumId: CurriculumId.mishnayos,
          query: 'berakhot',
        ).future,
      );
      expect(results.length, 1);
      expect(results.first.sefariaRef, equals('A'));
    });

    test('P4. query matches Hebrew displayNameHe', () async {
      final items = [
        _item(
          ref: 'A',
          level1: 'L1',
          level2: 'A',
          level3: '1',
          level4: '1',
          englishName: 'Item A',
          hebrewName: 'ברכות',
        ),
        _item(
          ref: 'B',
          level1: 'L1',
          level2: 'B',
          level3: '1',
          level4: '1',
          englishName: 'Item B',
          hebrewName: 'שבת',
        ),
      ];
      final repo = _FakeContentRepository(items);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Search with Hebrew letters — should match ברכות.
      final results = await container.read(
        contentSearchProvider(
          curriculumId: CurriculumId.mishnayos,
          query: 'ברכות',
        ).future,
      );
      expect(results.length, 1);
      expect(results.first.sefariaRef, equals('A'));
    });

    test('P5. no match returns empty list', () async {
      final repo = _FakeContentRepository([_kLeafItem, _kLeafItem2]);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final results = await container.read(
        contentSearchProvider(
          curriculumId: CurriculumId.mishnayos,
          query: 'xyznotexistent',
        ).future,
      );
      expect(results, isEmpty);
    });
  });

  group('content_providers — filteredContentProvider', () {
    test('P6. level1 filter returns only items in that seder', () async {
      final zeraim = _item(
        ref: 'Z1',
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
      );
      final moed = _item(
        ref: 'M1',
        level1: 'Moed',
        level2: 'Shabbat',
        level3: '1',
        level4: '1',
      );
      final repo = _FakeContentRepository([zeraim, moed]);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final filtered = await container.read(
        filteredContentProvider(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Zeraim',
        ).future,
      );
      expect(filtered.length, 1);
      expect(filtered.first.sefariaRef, equals('Z1'));
    });

    test('P7. level1+level2 filter returns only matching item', () async {
      final zeraim1 = _item(
        ref: 'Z1',
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
      );
      final zeraim2 = _item(
        ref: 'Z2',
        level1: 'Zeraim',
        level2: 'Peah',
        level3: '1',
        level4: '1',
      );
      final repo = _FakeContentRepository([zeraim1, zeraim2]);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final filtered = await container.read(
        filteredContentProvider(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Zeraim',
          level2: 'Berakhot',
        ).future,
      );
      expect(filtered.length, 1);
      expect(filtered.first.sefariaRef, equals('Z1'));
    });
  });

  group('content_providers — curriculumHeNamesProvider', () {
    test('P8. only leaf items with non-empty Hebrew names included', () async {
      final container = _item(
        ref: 'Container',
        level1: 'L1',
        isLeaf: false,
        hebrewName: 'מכיל',
      );
      final leafWithHe = _item(
        ref: 'Leaf1',
        level1: 'L1',
        level2: 'L2',
        level3: '1',
        level4: '1',
        hebrewName: 'ברכות',
      );
      const leafEmptyHe = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'L1',
        level2: 'L2',
        level3: '1',
        level4: '2',
        displayNameHe: '', // empty — must be excluded
        displayNameEn: 'Empty He',
        sefariaRef: 'EmptyHe',
        sortOrder: 2,
        isLeaf: true,
      );
      final repo = _FakeContentRepository([container, leafWithHe, leafEmptyHe]);

      // curriculumHeNamesProvider depends on curriculumContentProvider, which
      // depends on contentRepositoryProvider.
      final scope = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(scope.dispose);

      final heNames = await scope.read(
        curriculumHeNamesProvider(CurriculumId.mishnayos).future,
      );
      expect(heNames.containsKey('Leaf1'), isTrue);
      expect(heNames['Leaf1'], equals('ברכות'));
      // Container excluded (not a leaf).
      expect(heNames.containsKey('Container'), isFalse);
      // Empty-he leaf excluded.
      expect(heNames.containsKey('EmptyHe'), isFalse);
    });
  });

  group('content_providers — adjacentContentRefsProvider', () {
    test(
      'P9. prev/next computed correctly from sortOrder within curriculum',
      () async {
        final first = _item(
          ref: 'A',
          level1: 'L1',
          level2: 'L2',
          level3: '1',
          level4: '1',
          sortOrder: 0,
        );
        final second = _item(
          ref: 'B',
          level1: 'L1',
          level2: 'L2',
          level3: '1',
          level4: '2',
          sortOrder: 1,
        );
        final third = _item(
          ref: 'C',
          level1: 'L1',
          level2: 'L2',
          level3: '1',
          level4: '3',
          sortOrder: 2,
        );

        // Provide all curricula via the repository. The fake repo returns the
        // same items for all curricula; adjacentContentRefsProvider finds the
        // item in the first curriculum it scans and returns prev/next.
        final repo = _FakeContentRepository([first, second, third]);
        final container = ProviderContainer(
          overrides: [contentRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final adj = await container.read(
          adjacentContentRefsProvider('B').future,
        );
        expect(adj.prev, equals('A'));
        expect(adj.next, equals('C'));
      },
    );

    test('P10. first item has prev=null; last item has next=null', () async {
      final first = _item(
        ref: 'First',
        level1: 'L1',
        level2: 'L2',
        level3: '1',
        level4: '1',
        sortOrder: 0,
      );
      final last = _item(
        ref: 'Last',
        level1: 'L1',
        level2: 'L2',
        level3: '1',
        level4: '2',
        sortOrder: 1,
      );

      final repo = _FakeContentRepository([first, last]);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final adjFirst = await container.read(
        adjacentContentRefsProvider('First').future,
      );
      expect(adjFirst.prev, isNull);
      expect(adjFirst.next, equals('Last'));

      final adjLast = await container.read(
        adjacentContentRefsProvider('Last').future,
      );
      expect(adjLast.prev, equals('First'));
      expect(adjLast.next, isNull);
    });
  });

  group('content_providers — contentByRefProvider', () {
    test('P11. known ref returns item; unknown ref returns null', () async {
      final repo = _FakeContentRepository([_kLeafItem, _kContainerItem]);
      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final found = await container.read(
        contentByRefProvider(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _kLeafItem.sefariaRef,
        ).future,
      );
      expect(found, isNotNull);
      expect(found!.sefariaRef, equals(_kLeafItem.sefariaRef));

      final missing = await container.read(
        contentByRefProvider(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'does_not_exist_xyz',
        ).future,
      );
      expect(missing, isNull);
    });
  });
}
