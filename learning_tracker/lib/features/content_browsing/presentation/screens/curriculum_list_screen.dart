import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';

@RoutePage()
class CurriculumListScreen extends ConsumerWidget {
  const CurriculumListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Browse Content'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search curricula',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 20),
                const SizedBox(width: 12),
                Text(
                  'Search curricula...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section header
          Text(
            'CURRICULA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Curriculum cards
          ...CurriculumId.values.map(
            (curriculum) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CurriculumCard(curriculum: curriculum),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Activity section
          Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const _RecentActivityPlaceholder(),
        ],
      ),
    );
  }
}

class _CurriculumCard extends ConsumerWidget {
  const _CurriculumCard({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(curriculumContentProvider(curriculum));
    final completionAsync = ref.watch(dashboardCompletionPercentageProvider(curriculum));
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final percentage = completionAsync.asData?.value ?? 0.0;
    final pctDisplay = (percentage * 100).round();

    return contentAsync.when(
      data: (items) {
        final leafCount = items.where((item) => item.isLeaf).length;
        final containerCount = items.where((item) => !item.isLeaf).length;

        return _buildCard(
          context: context,
          curriculumColor: curriculumColor,
          pctDisplay: pctDisplay,
          percentage: percentage,
          leafCount: leafCount,
          containerCount: containerCount,
        );
      },
      loading: () => _buildCard(
        context: context,
        curriculumColor: curriculumColor,
        pctDisplay: pctDisplay,
        percentage: percentage,
        isLoading: true,
      ),
      error: (_, __) => _buildCard(
        context: context,
        curriculumColor: curriculumColor,
        pctDisplay: pctDisplay,
        percentage: percentage,
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required Color curriculumColor,
    required int pctDisplay,
    required double percentage,
    int leafCount = 0,
    int containerCount = 0,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: () {
        context.router.push(
          ContentHierarchyRoute(curriculumId: curriculum.storageKey),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              curriculumColor.withValues(alpha: 0.35),
              curriculumColor.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: curriculumColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curriculum.displayNameHe,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans Hebrew',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        curriculum.displayNameEn,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pctDisplay > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: curriculumColor),
                        const SizedBox(width: 4),
                        Text(
                          '$pctDisplay% Done',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8C519).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8C519),
                      ),
                    ),
                  ),
              ],
            ),
            if (percentage > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(curriculumColor),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (containerCount > 0) ...[
                  Text(
                    '$containerCount ${_getContainerLabel(curriculum)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (leafCount > 0)
                  Text(
                    '$leafCount ${_getLeafLabel(curriculum)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getContainerLabel(CurriculumId curriculum) {
    return switch (curriculum) {
      CurriculumId.mishnayos => 'Masechos',
      CurriculumId.bavli => 'Masechos',
      CurriculumId.yerushalmi => 'Masechos',
      CurriculumId.chumash || CurriculumId.torah => 'Books',
      _ => 'Sections',
    };
  }

  String _getLeafLabel(CurriculumId curriculum) {
    return switch (curriculum) {
      CurriculumId.mishnayos => 'Mishnayos',
      CurriculumId.bavli => 'Pages',
      CurriculumId.yerushalmi => 'Pages',
      CurriculumId.chumash || CurriculumId.torah => 'Parshiyos',
      _ => 'Items',
    };
  }
}

class _RecentActivityPlaceholder extends StatelessWidget {
  const _RecentActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8C519).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history, color: Color(0xFFE8C519), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start learning to see activity here',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your recent completions will appear below',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
