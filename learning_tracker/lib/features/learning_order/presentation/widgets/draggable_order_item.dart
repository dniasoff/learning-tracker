import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';

/// A single item tile in the learning order list.
///
/// When [showDragHandle] is true, wraps content with a
/// [ReorderableDragStartListener] to enable drag-and-drop.
class DraggableOrderItem extends ConsumerWidget {
  const DraggableOrderItem({
    super.key,
    required this.item,
    required this.index,
    this.showDragHandle = true,
  });

  final LearningOrderItem item;
  final int index;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hebrewOnly = ref.watch(hebrewTermsScriptProvider);

    return ListTile(
      key: ValueKey(item.sefariaRef),
      title: CurriculumLabel.local(
        item.sefariaRef,
        textDirection: hebrewOnly ? TextDirection.rtl : TextDirection.ltr,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: showDragHandle
          ? ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}
