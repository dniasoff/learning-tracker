import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/reorder_confirm_dialog.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/reset_order_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
          text: AppLocalizations.of(context)!.learningOrderScreenTitle(
            curriculumLabelText(ref, curriculum: widget.curriculumId),
          ),
        ),
        actions: [
          if (!isRestricted)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: AppLocalizations.of(context)!.resetToDefaultOrder,
              onPressed: () => _resetToDefault(context),
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () =>
              ref.refresh(learningOrderProvider(widget.curriculumId)),
        ),
        data: (_) {
          final items = _localOrder;
          if (items == null || items.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context)!.noItemsToOrder),
            );
          }

          if (isRestricted) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    AppLocalizations.of(context)!.controlledByParent,
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
            onReorderItem: (oldIndex, newIndex) =>
                _onReorder(oldIndex, newIndex),
          );
        },
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // Reorder-amnesty guard: warn the user if they have outstanding overdue
    // items that will be cleared by this reorder.
    final overdueCount = await ref.read(
      overdueCountForCurriculumProvider(widget.curriculumId).future,
    );
    if (!mounted) return;
    final confirmed = await ReorderConfirmDialog.showIfNeeded(
      context,
      overdueCount: overdueCount,
    );
    if (!confirmed || !mounted) return;

    final previous = _localOrder;
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

    // Persist asynchronously via use case.
    unawaited(_persistOrder(updated, previous));
  }

  Future<void> _persistOrder(
    List<LearningOrderItem> items,
    List<LearningOrderItem>? previous,
  ) async {
    final useCase = ref.read(saveLearningOrderUseCaseProvider);
    try {
      await useCase(widget.curriculumId, items);
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event:
            'learning_order_save_failed: curriculumId=${widget.curriculumId}',
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _localOrder = previous);
      _showOrderSaveError();
      return;
    }
    if (!mounted) return;
    // Invalidate provider so other screens see updated order.
    ref.invalidate(learningOrderProvider(widget.curriculumId));
  }

  void _showOrderSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.learningOrderSaveFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showOrderResetError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.learningOrderResetFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final confirmed = await ResetOrderDialog.show(context);
    if (!confirmed) return;

    final repository = ref.read(learningOrderRepositoryProvider);
    try {
      await repository.resetToDefault(widget.curriculumId);
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event:
            'learning_order_reset_failed: curriculumId=${widget.curriculumId}',
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _showOrderResetError();
      return;
    }
    if (!mounted) return;

    // Invalidate the provider, then await the fresh default order and seed it
    // into local state directly. Relying on a `_localOrder = null` reset plus
    // re-seeding via `orderAsync.whenData` in build() is racy: an invalidated
    // FutureProvider keeps exposing its previous (custom-order) value while the
    // refetch is loading, so a rebuild that lands first re-seeds the stale
    // custom order and the later default emission is then ignored — leaving the
    // UI showing the old order until manual re-navigation.
    ref.invalidate(learningOrderProvider(widget.curriculumId));
    final defaultOrder = await ref.read(
      learningOrderProvider(widget.curriculumId).future,
    );
    if (!mounted) return;
    setState(() {
      _localOrder = List.from(defaultOrder);
    });
  }
}
