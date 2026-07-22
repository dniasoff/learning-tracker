import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class ContentSearchScreen extends ConsumerStatefulWidget {
  const ContentSearchScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  ConsumerState<ContentSearchScreen> createState() =>
      _ContentSearchScreenState();
}

class _ContentSearchScreenState extends ConsumerState<ContentSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _debouncedQuery = '';

  CurriculumId? get _curriculumOrNull {
    try {
      return CurriculumId.values.firstWhere(
        (c) => c.storageKey == widget.curriculumId,
      );
    } on StateError {
      // Iterable.firstWhere throws StateError('No element') when no
      // CurriculumId matches — the expected "unknown curriculum id" case
      // this getter exists to convert to null (AUD-content_browsing-09,
      // EH-4). Narrowed from a bare `catch (_)` so an unrelated
      // programming-error Error subtype is not silently folded into the
      // same "just return null" branch.
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Mirrors [ContentHierarchyScreen._isChapterLevelRef]: returns true when
  /// [item] sits at the curriculum's [CurriculumLabels.maxBrowseDepth] and
  /// that depth is shallower than the full leaf depth. Such items should open
  /// the text reader directly rather than drill into a (broken) intermediate
  /// hierarchy screen.
  bool _isChapterLevelRef(CurriculumId curriculum, ContentItem item) {
    final maxDepth = CurriculumLabels.maxBrowseDepth(curriculum);
    if (maxDepth >= CurriculumLabels.depth(curriculum)) return false;
    final itemDepth = item.level4 != null
        ? 4
        : item.level3 != null
        ? 3
        : item.level2 != null
        ? 2
        : 1;
    return itemDepth == maxDepth;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _debouncedQuery = query.trim();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final curriculum = _curriculumOrNull;

    if (curriculum == null) {
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(text: AppLocalizations.of(context)!.searchTitle),
        ),
        body: Center(
          child: Text(
            AppLocalizations.of(
              context,
            )!.errorUnknownCurriculum(widget.curriculumId),
          ),
        ),
      );
    }

    final resultsAsync = _debouncedQuery.isEmpty
        ? null
        : ref.watch(
            contentSearchProvider(
              curriculumId: curriculum,
              query: _debouncedQuery,
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          inputFormatters: const [TrimLeadingSpaceFormatter()],
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchFieldHint(
              curriculumLabelText(ref, curriculum: curriculum),
            ),
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            // PP-18 fix: provide a clear (X) suffix icon so the user can reset
            // the query without backspacing through every character.
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: AppLocalizations.of(
                      context,
                    )!.contentSearchClearTooltip,
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          onChanged: _onSearchChanged,
        ),
      ),
      body: _buildBody(context, curriculum, resultsAsync),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CurriculumId curriculum,
    AsyncValue<List<ContentItem>>? resultsAsync,
  ) {
    // R4-7: gate the chazara review badge to whether any active track has
    // chazara enabled (default false while loading) — consistent with the
    // content hierarchy screen, so non-chazara users see no review badge.
    final showReviewBadge =
        ref.watch(anyActiveTrackHasChazaraProvider).asData?.value ?? false;
    if (resultsAsync == null) {
      return Center(
        child: Text(AppLocalizations.of(context)!.searchHintEnterTerm),
      );
    }

    return resultsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.noResultsForQuery(_debouncedQuery),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    l10n.noResultsForQueryHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ContentItemTile(
              item: item,
              curriculum: curriculum,
              showReviewBadge: showReviewBadge,
              showBreadcrumb: true,
              onTap: () {
                if (item.isLeaf || _isChapterLevelRef(curriculum, item)) {
                  context.router.push(
                    TextDisplayRoute(sefariaRef: item.sefariaRef),
                  );
                } else {
                  // Navigate into the hierarchy pre-filtered to this
                  // container's level path, mirroring _handleItemTap in
                  // ContentHierarchyScreen.
                  context.router.push(
                    ContentHierarchyRoute(
                      curriculumId: curriculum.storageKey,
                      level1: item.level1,
                      level2: item.level2,
                      level3: item.level3,
                      level4: item.level4,
                    ),
                  );
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.colors.brandCoralDeep,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.errorSearchError(error.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
