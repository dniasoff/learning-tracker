import 'package:flutter/material.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';

/// A single item tile in the learning order list.
///
/// When [showDragHandle] is true, wraps content with a
/// [ReorderableDragStartListener] to enable drag-and-drop.
class DraggableOrderItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final tile = ListTile(
      key: ValueKey(item.sefariaRef),
      title: Text(
        item.displayNameHe,
        textDirection: TextDirection.rtl,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(item.displayNameEn),
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

    return tile;
  }
}
