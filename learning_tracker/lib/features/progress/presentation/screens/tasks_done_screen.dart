import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_visuals.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/natural_sort.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';

/// Diameter of the curriculum icon in the section header. Sized to balance
/// with the title's `titleMedium` text height.
const double _curriculumIconSize = 22;

/// A single unique item learned (earliest completion per sefariaRef).
class _UniqueItem {
  final String sefariaRef;
  final DateTime firstCompletedAt;
  const _UniqueItem({required this.sefariaRef, required this.firstCompletedAt});
}

/// Groups completions by curriculum, deduplicating by sefariaRef and
/// keeping only the earliest completedAt for each.
Map<CurriculumId, List<_UniqueItem>> _groupUnique(List<Completion> all) {
  final earliest = <String, _UniqueItem>{};
  for (final c in all) {
    final key = '${c.curriculumId}:${c.sefariaRef}';
    final existing = earliest[key];
    if (existing == null || c.completedAt.isBefore(existing.firstCompletedAt)) {
      earliest[key] = _UniqueItem(
        sefariaRef: c.sefariaRef,
        firstCompletedAt: c.completedAt,
      );
    }
  }

  // Group by CurriculumId
  final result = <CurriculumId, List<_UniqueItem>>{};
  for (final c in all) {
    CurriculumId? id;
    try {
      id = CurriculumId.values.firstWhere(
        (e) => e.storageKey == c.curriculumId,
      );
    } on StateError {
      continue;
    }
    result.putIfAbsent(id, () => []);
  }
  // Populate with deduped items, oldest first
  for (final entry in earliest.entries) {
    final curriculumKey = entry.key.split(':').first;
    CurriculumId? id;
    try {
      id = CurriculumId.values.firstWhere((e) => e.storageKey == curriculumKey);
    } on StateError {
      continue;
    }
    result.putIfAbsent(id, () => []).add(entry.value);
  }
  // Within each curriculum: newest completion first, with a natural-order
  // sefariaRef tie-break so items completed on the same date appear in
  // seder/perek/mishna order rather than lexical ("1:10" before "1:2").
  for (final list in result.values) {
    list.sort((a, b) {
      final byDate = b.firstCompletedAt.compareTo(a.firstCompletedAt);
      if (byDate != 0) return byDate;
      return compareNaturalString(a.sefariaRef, b.sefariaRef);
    });
  }
  // Sort curricula by canonical enum order
  final sorted = Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index)),
  );
  return sorted;
}

@RoutePage()
class TasksDoneScreen extends ConsumerStatefulWidget {
  const TasksDoneScreen({super.key});

  @override
  ConsumerState<TasksDoneScreen> createState() => _TasksDoneScreenState();
}

class _TasksDoneScreenState extends ConsumerState<TasksDoneScreen> {
  final Set<CurriculumId> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final completionsAsync = ref.watch(allCompletionHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Tasks Done')),
      body: completionsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorDisplay(
          message: 'Failed to load tasks: $e',
          onRetry: () => ref.invalidate(allCompletionHistoryProvider),
        ),
        data: (completions) {
          if (completions.isEmpty) {
            return _EmptyState();
          }
          final grouped = _groupUnique(completions);
          if (grouped.isEmpty) {
            return _EmptyState();
          }
          final totalUnique = grouped.values.fold(
            0,
            (sum, list) => sum + list.length,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SummaryHeader(totalUnique: totalUnique),
              const SizedBox(height: 12),
              for (final entry in grouped.entries)
                _CurriculumSection(
                  curriculumId: entry.key,
                  items: entry.value,
                  isExpanded: _expanded.contains(entry.key),
                  onToggle: () => setState(() {
                    if (_expanded.contains(entry.key)) {
                      _expanded.remove(entry.key);
                    } else {
                      _expanded.add(entry.key);
                    }
                  }),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.totalUnique});
  final int totalUnique;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.brandBlueSoft.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, color: AppTheme.brandBlue),
          const SizedBox(width: 10),
          Text(
            '$totalUnique unique tasks completed',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.brandBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurriculumSection extends StatelessWidget {
  const _CurriculumSection({
    required this.curriculumId,
    required this.items,
    required this.isExpanded,
    required this.onToggle,
  });

  final CurriculumId curriculumId;
  final List<_UniqueItem> items;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    curriculumIcon(curriculumId),
                    color: AppTheme.getCurriculumColor(curriculumId),
                    size: _curriculumIconSize,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CurriculumLabel.curriculum(curriculumId),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} task${items.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.brandInkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.brandInkMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            ...items.map((item) => _ItemRow(item: item)),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final _UniqueItem item;

  @override
  Widget build(BuildContext context) {
    final date = item.firstCompletedAt.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final formatted = DateFormat.yMMMd(locale).format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: CurriculumLabel.local(
              item.sefariaRef,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            formatted,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.brandInkMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks completed yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first learning session to see tasks here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
