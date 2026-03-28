import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Stage 1: Pick ONE curriculum from all 9 available options.
///
/// Displays Hebrew names. Single tap selection advances immediately.
class CurriculumPickerStep extends StatelessWidget {
  const CurriculumPickerStep({
    required this.onSelected,
    this.isOnboarding = false,
    super.key,
  });

  final ValueChanged<CurriculumId> onSelected;
  final bool isOnboarding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isOnboarding
                ? 'What would you like to learn?'
                : 'Select a Curriculum',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose one curriculum for this track.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: CurriculumId.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final curriculum = CurriculumId.values[index];
                return _CurriculumTile(
                  curriculum: curriculum,
                  onTap: () => onSelected(curriculum),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CurriculumTile extends StatelessWidget {
  const _CurriculumTile({required this.curriculum, required this.onTap});

  final CurriculumId curriculum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curriculum.displayNameHe,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      curriculum.displayNameEn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
