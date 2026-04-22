import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
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
              color: AppTheme.brandCreamCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.brandOutline),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppTheme.brandInkMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Search curricula...',
                  style: TextStyle(color: AppTheme.brandInkMuted, fontSize: 15),
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
              color: AppTheme.brandInkMuted,
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
              color: AppTheme.brandInkMuted,
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
    final completionAsync = ref.watch(
      dashboardCompletionPercentageProvider(curriculum),
    );
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final percentage = completionAsync.asData?.value ?? 0.0;
    final pctDisplay = formatFractionAsPercent(percentage);

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
    required String pctDisplay,
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
          border: Border.all(color: curriculumColor.withValues(alpha: 0.2)),
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
                          color: AppTheme.brandInk,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        curriculum.displayNameHe,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.brandInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (percentage > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCreamSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: curriculumColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pctDisplay Done',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandInk,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGoldSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brandGoldDeep,
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
                  backgroundColor: AppTheme.brandOutline.withValues(alpha: 0.5),
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
                      color: AppTheme.brandInkMuted,
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
                      color: AppTheme.brandInkMuted,
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
      CurriculumId.chumash => 'Books',
      CurriculumId.mishnehTorah => 'Seforim',
      _ => 'Sections',
    };
  }

  String _getLeafLabel(CurriculumId curriculum) {
    return switch (curriculum) {
      CurriculumId.mishnayos => 'Mishnayos',
      CurriculumId.bavli => 'Pages',
      CurriculumId.yerushalmi => 'Pages',
      CurriculumId.chumash => 'Parshiyos',
      CurriculumId.mishnehTorah => 'Halachos',
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
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brandOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.brandGoldSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history,
              color: AppTheme.brandGoldDeep,
              size: 20,
            ),
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
                    color: AppTheme.brandInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your recent completions will appear below',
                  style: TextStyle(fontSize: 12, color: AppTheme.brandInkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
