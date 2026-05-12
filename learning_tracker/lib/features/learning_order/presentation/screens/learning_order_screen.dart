import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/learning_order/presentation/providers/learning_order_providers.dart';
import 'package:learning_tracker/features/learning_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/features/learning_order/presentation/widgets/reset_order_dialog.dart';

@RoutePage()
class LearningOrderScreen extends ConsumerStatefulWidget {
  const LearningOrderScreen({super.key, required this.curriculumId});

  final CurriculumId curriculumId;

  @override
  ConsumerState<LearningOrderScreen> createState() =>
      _LearningOrderScreenState();
}

class _LearningOrderScreenState extends ConsumerState<LearningOrderScreen> {
  /// Local optimistic list — updated immediately on drag before async save.
  List<LearningOrderItem>? _localOrder;

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(learningOrderProvider(widget.curriculumId));
    final restrictedAsync = ref.watch(orderingRestrictedProvider);

    // Sync provider data into local state on first load (or after reset)
    orderAsync.whenData((items) {
      if (_localOrder == null) {
        _localOrder = List.from(items);
      }
    });

    final isRestricted = restrictedAsync.asData?.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text:
              '${curriculumLabelText(ref, curriculum: widget.curriculumId)} '
              'Order',
        ),
        actions: [
          if (!isRestricted)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset to Default Order',
              onPressed: () => _resetToDefault(context),
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading order: $e')),
        data: (_) {
          final items = _localOrder;
          if (items == null || items.isEmpty) {
            return const Center(child: Text('No items to order.'));
          }

          if (isRestricted) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Controlled by parent',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => DraggableOrderItem(
                      item: items[index],
                      index: index,
                      showDragHandle: false,
                    ),
                  ),
                ),
              ],
            );
          }

          return ReorderableListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => DraggableOrderItem(
              key: ValueKey(items[index].sefariaRef),
              item: items[index],
              index: index,
            ),
            onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex),
          );
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<LearningOrderItem>.from(_localOrder!);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    // Update userSortOrder to reflect new positions
    final updated = items
        .asMap()
        .entries
        .map(
          (e) => e.value.copyWith(userSortOrder: e.key, isCustomOrdered: true),
        )
        .toList();

    setState(() {
      _localOrder = updated;
    });

    // Persist asynchronously
    final repository = ref.read(learningOrderRepositoryProvider);
    repository.saveOrder(widget.curriculumId, updated).then((_) {
      // Invalidate provider so other screens see updated order
      ref.invalidate(learningOrderProvider(widget.curriculumId));
    });
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final confirmed = await ResetOrderDialog.show(context);
    if (!confirmed) return;

    final repository = ref.read(learningOrderRepositoryProvider);
    await repository.resetToDefault(widget.curriculumId);

    // Reset local state so next build reloads from provider
    setState(() {
      _localOrder = null;
    });

    ref.invalidate(learningOrderProvider(widget.curriculumId));
  }
}
