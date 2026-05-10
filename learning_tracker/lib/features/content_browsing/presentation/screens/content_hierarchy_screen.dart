import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/transliteration_variant_provider.dart';

@RoutePage()
class ContentHierarchyScreen extends ConsumerStatefulWidget {
  const ContentHierarchyScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
    this.level1,
    this.level2,
    this.level3,
    this.level4,
  });

  final String curriculumId;
  final String? level1;
  final String? level2;
  final String? level3;
  final String? level4;

  @override
  ConsumerState<ContentHierarchyScreen> createState() =>
      _ContentHierarchyScreenState();
}

class _ContentHierarchyScreenState
    extends ConsumerState<ContentHierarchyScreen> {
  List<String> _navigationStack = [];

  @override
  void initState() {
    super.initState();
    _navigationStack = [
      if (widget.level1 != null) widget.level1!,
      if (widget.level2 != null) widget.level2!,
      if (widget.level3 != null) widget.level3!,
      if (widget.level4 != null) widget.level4!,
    ];
  }

  CurriculumId? get _curriculumOrNull {
    final matches = CurriculumId.values.where(
      (c) => c.storageKey == widget.curriculumId,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  String? get _currentLevel1 =>
      _navigationStack.isNotEmpty ? _navigationStack[0] : null;
  String? get _currentLevel2 =>
      _navigationStack.length > 1 ? _navigationStack[1] : null;
  String? get _currentLevel3 =>
      _navigationStack.length > 2 ? _navigationStack[2] : null;
  String? get _currentLevel4 =>
      _navigationStack.length > 3 ? _navigationStack[3] : null;

  @override
  Widget build(BuildContext context) {
    final curriculum = _curriculumOrNull;

    if (curriculum == null) {
      return Scaffold(
        appBar: AppBar(title: const AppBarTitle(text: 'Unknown Curriculum')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.brandCoralDeep,
              ),
              const SizedBox(height: 16),
              Text(
                'Unknown curriculum: "${widget.curriculumId}"',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final configAsync = ref.watch(
      curriculumHierarchyConfigProvider(curriculum),
    );
    final itemsAsync = ref.watch(
      filteredContentProvider(
        curriculumId: curriculum,
        level1: _currentLevel1,
        level2: _currentLevel2,
        level3: _currentLevel3,
        level4: _currentLevel4,
      ),
    );

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          child: Text(
            'Browse Content',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.2,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigationStack.isNotEmpty
              ? _navigateUp
              : () => context.router.maybePop(),
        ),
      ),
      body: Column(
        children: [
          // Breadcrumb / curriculum chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: curriculumColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    ref.watch(hebrewTermsScriptProvider)
                        ? curriculum.displayNameHe
                        : curriculum.displayNameEn,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: curriculumColor,
                    ),
                  ),
                ),
                if (_navigationStack.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: configAsync.when(
                      data: (config) {
                        final hebrewTerms = ref.watch(
                          hebrewTermsScriptProvider,
                        );
                        final variant = ref.watch(
                          transliterationVariantProvider,
                        );
                        // Every breadcrumb segment goes through the renderer
                        // — same path as row labels and reader titles.
                        final segments =
                            CurriculumLabelRenderer.renderBreadcrumb(
                              curriculumId: curriculum,
                              rawSegmentValues: _navigationStack,
                              useHebrew: hebrewTerms,
                              transliterationVariant: variant,
                            );
                        return BreadcrumbNavigation(
                          curriculum: curriculum,
                          levelLabels: config.levelLabels,
                          navigationStack: segments,
                          onBreadcrumbTap: _navigateToLevel,
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content list
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No content available',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final hebrewTerms = ref.watch(hebrewTermsScriptProvider);
                final variant = ref.watch(transliterationVariantProvider);
                final groupedItems = _groupItemsByNextLevel(
                  items,
                  hebrewTerms,
                  variant,
                );

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupedItems.length,
                  itemBuilder: (context, index) {
                    final item = groupedItems[index];
                    return ContentItemTile(
                      item: item,
                      curriculum: curriculum,
                      onTap: () => _handleItemTap(item),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error,
                      size: 48,
                      color: AppTheme.brandCoralDeep,
                    ),
                    const SizedBox(height: 16),
                    Text('Error loading content: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the list of rows shown at the current drill-down depth.
  ///
  /// All display strings — every row's Hebrew and English title — flow
  /// through `CurriculumLabelRenderer`. The screen no longer carries any
  /// bespoke prefix-stripping or amud-letter mapping; the renderer is the
  /// single source of truth.
  ///
  /// Browse depth is capped at `CurriculumLabels.maxBrowseDepth(curriculum)`
  /// so Chumash / Nach / Tanach never drill into pasuk-level rows — the
  /// chapter row opens the reader directly instead.
  List<ContentItem> _groupItemsByNextLevel(
    List<ContentItem> items,
    bool hebrewTerms,
    TransliterationVariant variant,
  ) {
    final curriculum = _curriculumOrNull;
    if (curriculum == null) return items;
    final currentDepth = _navigationStack.length;
    final maxBrowseDepth = CurriculumLabels.maxBrowseDepth(curriculum);
    if (currentDepth >= maxBrowseDepth) return const [];

    final nextLevel = currentDepth + 1;
    final uniqueItems = <String, ContentItem>{};

    for (final item in items) {
      final nextLevelValue = _getNextLevelValue(item, currentDepth);
      if (nextLevelValue == null || uniqueItems.containsKey(nextLevelValue)) {
        continue;
      }

      final renderedHe = CurriculumLabelRenderer.renderValue(
        curriculumId: curriculum,
        level: nextLevel,
        rawValue: nextLevelValue,
        useHebrew: true,
        hebrewName: !item.isLeaf ? item.displayNameHe : null,
        parentL1Value: item.level1,
        transliterationVariant: variant,
      );
      final renderedEn = CurriculumLabelRenderer.renderValue(
        curriculumId: curriculum,
        level: nextLevel,
        rawValue: nextLevelValue,
        useHebrew: false,
        hebrewName: !item.isLeaf ? item.displayNameHe : null,
        parentL1Value: item.level1,
        transliterationVariant: variant,
      );

      uniqueItems[nextLevelValue] = ContentItem(
        curriculumId: item.curriculumId,
        level1: item.level1,
        level2: currentDepth >= 1 ? item.level2 : null,
        level3: currentDepth >= 2 ? item.level3 : null,
        level4: currentDepth >= 3 ? item.level4 : null,
        displayNameHe: renderedHe,
        displayNameEn: renderedEn,
        sefariaRef: item.sefariaRef,
        sortOrder: item.sortOrder,
        isLeaf: item.isLeaf,
      );
    }

    return uniqueItems.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  String? _getNextLevelValue(ContentItem item, int currentDepth) {
    return switch (currentDepth) {
      0 => item.level1,
      1 => item.level2,
      2 => item.level3,
      3 => item.level4,
      _ => null,
    };
  }

  void _handleItemTap(ContentItem item) {
    if (item.isLeaf || _isChapterLevelRef(item)) {
      context.router.push(TextDisplayRoute(sefariaRef: item.sefariaRef));
    } else {
      _drillDown(item);
    }
  }

  /// Returns true when tapping this item should open the text reader directly.
  /// For Chumash/Nach/Tanach, chapter-level refs (e.g. 'Genesis 1') open text
  /// rather than drilling into individual verses.
  bool _isChapterLevelRef(ContentItem item) {
    final curriculum = _curriculumOrNull;
    if (curriculum == null) return false;
    if (curriculum != CurriculumId.chumash &&
        curriculum != CurriculumId.nach &&
        curriculum != CurriculumId.tanach)
      return false;
    // Chapter ref: '{Book} {digits}' with no colon (e.g., 'Genesis 1', 'Joshua 3').
    return !item.sefariaRef.contains(':') &&
        RegExp(r'^.+ \d+$').hasMatch(item.sefariaRef);
  }

  void _drillDown(ContentItem item) {
    setState(() {
      final currentDepth = _navigationStack.length;
      final nextValue = _getNextLevelValue(item, currentDepth);

      if (nextValue != null && currentDepth < 4) {
        _navigationStack = [..._navigationStack, nextValue];
      }
    });
  }

  void _navigateUp() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack = _navigationStack.sublist(
          0,
          _navigationStack.length - 1,
        );
      });
    }
  }

  void _navigateToLevel(int level) {
    if (level < _navigationStack.length) {
      setState(() {
        _navigationStack = _navigationStack.sublist(0, level + 1);
      });
    }
  }
}
