import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Read-only review schedule display for program tracks that have
/// defined chazara stages (chazara is fixed by the program).
class ChazaraReadOnlyStep extends StatelessWidget {
  const ChazaraReadOnlyStep({
    required this.programName,
    required this.stages,
    required this.onContinue,
    super.key,
  });

  final String programName;

  /// Raw stage objects decoded from program.stagesConfig (non-learn stages).
  final List<dynamic> stages;

  final VoidCallback onContinue;

  static String normalizeStageName(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Review stage';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review Schedule',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review stages set by $programName',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppTheme.brandBlueDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This schedule is fixed by the program and cannot be edited.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandBlueDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: stages.isEmpty
                ? Center(
                    child: Text(
                      'No review stages are configured for this program.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.brandInkMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: stages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final stage = stages[index] as Map<String, dynamic>;
                      final name = normalizeStageName(
                        stage['stage'].toString(),
                      );
                      final delay = stage['delay_days'];
                      final delayLabel = switch (delay) {
                        final int value when value == 1 => 'After 1 day',
                        final int value => 'After $value days',
                        final String value => 'After $value days',
                        _ => 'Scheduled by program',
                      };

                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFE7EAF1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFE9ECFF),
                                child: Text(
                                  '${index + 1}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppTheme.brandBlueDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      delayLabel,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTheme.brandInkMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.lock_rounded,
                                size: 18,
                                color: AppTheme.brandInkMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
