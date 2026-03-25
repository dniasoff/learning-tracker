import 'package:flutter/material.dart';

/// Displays a compact "Nx" badge showing the total review count for a content item.
///
/// Returns [SizedBox.shrink] when count is 0 (AC-6: no "0x" clutter).
class ReviewCountBadge extends StatelessWidget {
  const ReviewCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${count}x',
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
