import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';

/// Stage 2: Join a calendar program or continue self-paced.
///
/// Loads programs via [LearningProgramRepository] — no hardcoded IDs.
/// Auto-skipped if no programs exist for the selected curriculum.
class ProgramSelectionStep extends StatefulWidget {
  const ProgramSelectionStep({
    required this.curriculumId,
    required this.onSelected,
    super.key,
  });

  final CurriculumId curriculumId;

  /// Called with (programId, programName, fullProgram) or (null, null, null) for self-paced.
  final void Function(
    int? programId,
    String? programName,
    LearningProgramData? program,
  )
  onSelected;

  @override
  State<ProgramSelectionStep> createState() => _ProgramSelectionStepState();
}

class _ProgramSelectionStepState extends State<ProgramSelectionStep> {
  late final List<LearningProgramData> _programs;
  bool _didAutoSkip = false;

  @override
  void initState() {
    super.initState();
    _programs = LearningProgramRepository.instance
        .getProgramsByCurriculumType(widget.curriculumId.storageKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_programs.isEmpty) {
      if (!_didAutoSkip) {
        _didAutoSkip = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSelected(null, null, null);
        });
      }
      return const SizedBox.shrink();
    }

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
          Expanded(
            child: ListView(
              children: [
                ..._programs.map(
                  (program) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.onSelected(
                          program.id,
                          program.displayName,
                          program,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      program.displayName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      program.name
                                          .replaceAll('_', ' ')
                                          .split(' ')
                                          .map(
                                            (w) =>
                                                '${w[0].toUpperCase()}${w.substring(1)}',
                                          )
                                          .join(' '),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => widget.onSelected(null, null, null),
                  child: const Text('Self-paced (no program)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
