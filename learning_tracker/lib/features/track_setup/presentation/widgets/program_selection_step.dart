import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Stage 3: Join a calendar program or continue self-paced.
///
/// Auto-skipped if no programs exist for the selected curriculum.
class ProgramSelectionStep extends StatelessWidget {
  const ProgramSelectionStep({
    required this.curriculumId,
    required this.onSelected,
    super.key,
  });

  final CurriculumId curriculumId;
  final void Function(int? programId, String? programName) onSelected;

  List<_ProgramOption> get _availablePrograms {
    return switch (curriculumId) {
      CurriculumId.bavli => [
        const _ProgramOption(name: 'דף היומי', englishName: 'Daf Yomi', id: 1),
        const _ProgramOption(name: 'אורייתא', englishName: 'Oraysa', id: 3),
      ],
      CurriculumId.mishnaBerurah => [
        const _ProgramOption(name: 'דרשו', englishName: 'Dirshu', id: 2),
      ],
      _ => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final programs = _availablePrograms;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join a Program?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Follow a global study calendar, or learn at your own pace.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ...programs.map(
            (program) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onSelected(program.id, program.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                program.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                program.englishName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.calendar_month,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => onSelected(null, null),
            child: const Text('Self-paced (no program)'),
          ),
        ],
      ),
    );
  }
}

class _ProgramOption {
  const _ProgramOption({
    required this.name,
    required this.englishName,
    required this.id,
  });

  final String name;
  final String englishName;
  final int id;
}
