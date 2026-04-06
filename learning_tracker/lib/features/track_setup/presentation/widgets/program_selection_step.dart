import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';

/// Stage 2: Join a calendar program or continue self-paced.
///
/// Loads programs from DB via [LearningProgramDao] — no hardcoded IDs.
/// Auto-skipped if no programs exist for the selected curriculum.
class ProgramSelectionStep extends ConsumerStatefulWidget {
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
    LearningProgram? program,
  )
  onSelected;

  @override
  ConsumerState<ProgramSelectionStep> createState() =>
      _ProgramSelectionStepState();
}

class _ProgramSelectionStepState extends ConsumerState<ProgramSelectionStep> {
  late final Future<List<LearningProgram>> _programsFuture;
  bool _didAutoSkip = false;

  @override
  void initState() {
    super.initState();
    final contentDb = ref.read(contentDatabaseProvider);
    _programsFuture = contentDb.contentLearningProgramDao
        .getProgramsByCurriculumType(widget.curriculumId.storageKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<LearningProgram>>(
      future: _programsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final programs = snapshot.data ?? [];

        if (programs.isEmpty) {
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
                    ...programs.map(
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
      },
    );
  }
}
