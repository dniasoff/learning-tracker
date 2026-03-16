import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';

@RoutePage()
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _ScreenPhase { selection, importing, goalSetup, done, error }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _selected = <CurriculumId>{};
  var _phase = _ScreenPhase.selection;
  CurriculumImportProgress? _importProgress;
  List<CurriculumImportResult> _failures = [];

  // Goal setup state
  late List<CurriculumId> _goalSetupQueue;
  int _goalSetupIndex = 0;

  Future<void> _startImport() async {
    if (_selected.isEmpty) return;

    setState(() => _phase = _ScreenPhase.importing);

    final service = ref.read(curriculumImportServiceProvider);

    await for (final progress in service.importAll(_selected.toList())) {
      if (!mounted) return;
      setState(() => _importProgress = progress);
    }

    if (!mounted) return;

    final failures = _importProgress?.failures ?? [];
    if (failures.isEmpty) {
      _startGoalSetup();
    } else {
      setState(() {
        _phase = _ScreenPhase.error;
        _failures = failures;
      });
    }
  }

  Future<void> _retryFailed() async {
    if (_failures.isEmpty) return;

    setState(() => _phase = _ScreenPhase.importing);

    final service = ref.read(curriculumImportServiceProvider);
    final failedIds = _failures.map((f) => f.curriculumId).toList();

    await for (final progress in service.importAll(failedIds)) {
      if (!mounted) return;
      setState(() => _importProgress = progress);
    }

    if (!mounted) return;

    final newFailures = _importProgress?.failures ?? [];
    if (newFailures.isEmpty) {
      _startGoalSetup();
    } else {
      setState(() {
        _phase = _ScreenPhase.error;
        _failures = newFailures;
      });
    }
  }

  void _startGoalSetup() {
    _goalSetupQueue = _selected.toList();
    _goalSetupIndex = 0;
    if (_goalSetupQueue.isEmpty) {
      _finishOnboarding();
      return;
    }
    setState(() => _phase = _ScreenPhase.goalSetup);
  }

  Future<void> _onGoalResult(GoalFormResult? result) async {
    if (result != null) {
      final goalRepo = ref.read(goalRepositoryProvider);
      await goalRepo.createGoal(
        curriculumId: _goalSetupQueue[_goalSetupIndex],
        targetPercent: result.targetPercent,
        targetDate: result.targetDate,
        description: result.description,
      );
    }
    // Move to next curriculum or finish
    _goalSetupIndex++;
    if (_goalSetupIndex >= _goalSetupQueue.length) {
      unawaited(_finishOnboarding());
    } else {
      setState(() {}); // Refresh to show next curriculum
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _phase = _ScreenPhase.done);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Curricula')),
      body: switch (_phase) {
        _ScreenPhase.selection => _buildSelection(theme),
        _ScreenPhase.importing => _buildImporting(theme),
        _ScreenPhase.goalSetup => _buildGoalSetup(theme),
        _ScreenPhase.done => _buildDone(theme),
        _ScreenPhase.error => _buildError(theme),
      },
    );
  }

  Widget _buildSelection(ThemeData theme) {
    final configsAsync = ref.watch(allCurriculaConfigsProvider);

    return configsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load curricula: $e')),
      data: (configs) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Choose which curricula to track',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'You can add more later from Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: CurriculumId.values.length,
              itemBuilder: (context, index) {
                final curriculum = CurriculumId.values[index];
                final config = configs[curriculum];
                return _CurriculumCard(
                  curriculum: curriculum,
                  config: config,
                  isSelected: _selected.contains(curriculum),
                  onTap: () {
                    setState(() {
                      if (_selected.contains(curriculum)) {
                        _selected.remove(curriculum);
                      } else {
                        _selected.add(curriculum);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: _selected.isNotEmpty ? _startImport : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImporting(ThemeData theme) {
    final progress = _importProgress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Importing curricula...', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            if (progress != null) ...[
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 16),
              Text(
                '${progress.currentCurriculum.displayNameEn} '
                '(${progress.current}/${progress.total})',
                style: theme.textTheme.bodyLarge,
              ),
            ] else ...[
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSetup(ThemeData theme) {
    final curriculum = _goalSetupQueue[_goalSetupIndex];
    final configsAsync = ref.watch(allCurriculaConfigsProvider);
    final totalItems = configsAsync.whenOrNull(
      data: (configs) => configs[curriculum]?.totalItems,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set a goal for ${curriculum.displayNameEn}',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_goalSetupIndex + 1} of ${_goalSetupQueue.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (totalItems != null) ...[
            const SizedBox(height: 4),
            Text(
              '$totalItems items',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<GoalFormResult>(
                MaterialPageRoute<GoalFormResult>(
                  builder: (_) => GoalSetupScreen(
                    curriculumId: curriculum,
                    totalItems: totalItems,
                  ),
                ),
              );
              if (mounted) {
                await _onGoalResult(result);
              }
            },
            child: const Text('Set Goal'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _onGoalResult(null),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('All set!', style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Some imports failed', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final failure in _failures)
              Text(
                '${failure.curriculumId.displayNameEn}: ${failure.error}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _retryFailed,
              child: const Text('Retry Failed'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurriculumCard extends StatelessWidget {
  const _CurriculumCard({
    required this.curriculum,
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  final CurriculumId curriculum;
  final CurriculumHierarchyConfig? config;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getCurriculumColor(curriculum);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curriculum.displayNameEn,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : null,
                        ),
                      ),
                      if (config != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${config!.totalItems} items',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          config!.levelLabels.join(' > '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: color)
                else
                  Icon(
                    Icons.circle_outlined,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
