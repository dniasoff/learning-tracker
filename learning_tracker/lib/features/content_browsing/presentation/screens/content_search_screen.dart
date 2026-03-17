import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';

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
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
        appBar: AppBar(title: const AppBarTitle(text: 'Search')),
        body: Center(
          child: Text('Unknown curriculum: "${widget.curriculumId}"'),
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
          decoration: InputDecoration(
            hintText: 'Search ${curriculum.displayNameEn}…',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
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
    if (resultsAsync == null) {
      return const Center(child: Text('Enter a search term above'));
    }

    return resultsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No results for "$_debouncedQuery"',
              textAlign: TextAlign.center,
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
              onTap: () {
                if (item.isLeaf) {
                  context.router.push(
                    TextDisplayRoute(sefariaRef: item.sefariaRef),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Search error: $error'),
          ],
        ),
      ),
    );
  }
}
