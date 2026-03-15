import 'package:flutter/material.dart';

/// Summary header that displays the composed schedule summary text
/// and a toggle button between unified and grouped views.
class DailyScheduleHeader extends StatelessWidget {
  const DailyScheduleHeader({
    required this.summary,
    required this.isGroupedView,
    required this.onToggleView,
    super.key,
  });

  final String summary;
  final bool isGroupedView;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isGroupedView ? Icons.view_list : Icons.view_module,
            ),
            tooltip: isGroupedView ? 'Unified view' : 'Grouped view',
            onPressed: onToggleView,
          ),
        ],
      ),
    );
  }
}
