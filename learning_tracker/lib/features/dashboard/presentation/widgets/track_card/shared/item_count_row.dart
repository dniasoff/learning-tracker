import 'package:flutter/material.dart';

/// Shows "{completed} / {total} items complete".
class ItemCountRow extends StatelessWidget {
  const ItemCountRow({
    super.key,
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$completed / $total items complete',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
