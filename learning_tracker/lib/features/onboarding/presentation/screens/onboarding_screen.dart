import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/suggested_thresholds_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/rewards_setup_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';

@RoutePage()
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _ScreenPhase {
  selection,
  importing,
  scopeSelection,
  learningProcessWizard,
  bulkMark,
  goalSetup,
  rewardsSetup,
  done,
  error,
}

enum _CurriculumStatus { notStarted, importing, done, failed }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _selected = <CurriculumId>{};
  var _phase = _ScreenPhase.selection;
  CurriculumImportProgress? _importProgress;
  List<CurriculumImportResult> _failures = [];
  int _originalTotal = 0;
  final _curriculumStatuses = <CurriculumId, _CurriculumStatus>{};

  void _updateStatuses(CurriculumImportProgress progress) {
    for (final result in progress.results) {
      _curriculumStatuses[result.curriculumId] = result.success
          ? _CurriculumStatus.done
          : _CurriculumStatus.failed;
    }
    // Mark the one currently being processed as importing if not yet in results
    if (!progress.results.any(
      (r) => r.curriculumId == progress.currentCurriculum,
    )) {
      _curriculumStatuses[progress.currentCurriculum] =
          _CurriculumStatus.importing;
    }
  }

  // Scope selection state
  late List<CurriculumId> _scopeQueue;
  int _scopeIndex = 0;

  // Wizard state
  late List<CurriculumId> _wizardQueue;
  int _wizardIndex = 0;
  bool _wizardLaunched = false;

  // Bulk mark state
  late List<CurriculumId> _bulkMarkQueue;
  int _bulkMarkIndex = 0;
  bool _bulkMarkLaunched = false;

  // Goal setup state
  late List<CurriculumId> _goalSetupQueue;
  int _goalSetupIndex = 0;

  Future<void> _startImport() async {
    if (_selected.isEmpty) return;

    setState(() {
      _phase = _ScreenPhase.importing;
      _originalTotal = _selected.length;
      for (final id in _selected) {
        _curriculumStatuses[id] = _CurriculumStatus.notStarted;
      }
    });

    final service = ref.read(curriculumImportServiceProvider);

    await for (final progress in service.importAll(_selected.toList())) {
      if (!mounted) return;
      setState(() {
        _importProgress = progress;
        _updateStatuses(progress);
      });
    }

    if (!mounted) return;

    final failures = _importProgress?.failures ?? [];
    if (failures.isEmpty) {
      _startScopeSelection();
    } else {
      setState(() {
        _phase = _ScreenPhase.error;
        _failures = failures;
      });
    }
  }

  Future<void> _retryFailed() async {
    if (_failures.isEmpty) return;

    setState(() {
      _phase = _ScreenPhase.importing;
      for (final f in _failures) {
        _curriculumStatuses[f.curriculumId] = _CurriculumStatus.notStarted;
      }
    });

    final service = ref.read(curriculumImportServiceProvider);
    final failedIds = _failures.map((f) => f.curriculumId).toList();

    await for (final progress in service.importAll(failedIds)) {
      if (!mounted) return;
      setState(() {
        _importProgress = progress;
        _updateStatuses(progress);
      });
    }

    if (!mounted) return;

    final newFailures = _importProgress?.failures ?? [];
    if (newFailures.isEmpty) {
      _startScopeSelection();
    } else {
      setState(() {
        _phase = _ScreenPhase.error;
        _failures = newFailures;
      });
    }
  }

  void _startScopeSelection() {
    _scopeQueue = _selected.toList();
    _scopeIndex = 0;
    if (_scopeQueue.isEmpty) {
      _startLearningProcessWizard();
      return;
    }
    setState(() => _phase = _ScreenPhase.scopeSelection);
  }

  void _onScopeSelectionDone() {
    _scopeIndex++;
    if (_scopeIndex >= _scopeQueue.length) {
      _startLearningProcessWizard();
    } else {
      setState(() {}); // Show next curriculum's scope selection
    }
  }

  void _startLearningProcessWizard() {
    _wizardQueue = _selected.toList();
    _wizardIndex = 0;
    if (_wizardQueue.isEmpty) {
      _startBulkMark();
      return;
    }
    setState(() => _phase = _ScreenPhase.learningProcessWizard);
  }

  Future<void> _onWizardResult(LearningProcessWizardResult? result) async {
    if (result != null) {
      final wizardService = ref.read(learningProcessWizardServiceProvider);
      await wizardService.applyWizardResult(result.wizardResult);
    }
    _wizardIndex++;
    if (_wizardIndex >= _wizardQueue.length) {
      _startBulkMark();
    } else {
      _wizardLaunched = false;
      setState(() {});
    }
  }

  void _startBulkMark() {
    _bulkMarkQueue = _selected.toList();
    _bulkMarkIndex = 0;
    if (_bulkMarkQueue.isEmpty) {
      _startGoalSetup();
      return;
    }
    setState(() => _phase = _ScreenPhase.bulkMark);
  }

  Future<void> _onBulkMarkResult(BulkMarkResult? result) async {
    _bulkMarkIndex++;
    if (_bulkMarkIndex >= _bulkMarkQueue.length) {
      _startGoalSetup();
    } else {
      setState(() {}); // Show next curriculum's bulk mark screen
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
        dateType: result.dateType,
      );
      // Invalidate the scheduler so it picks up the new goal deadline.
      ref.invalidate(allDailyTasksProvider);
    }
    // Move to next curriculum or proceed to rewards setup
    _goalSetupIndex++;
    if (_goalSetupIndex >= _goalSetupQueue.length) {
      unawaited(
        _startRewardsSetup().catchError((Object e) {
          AppLogger.instance.error('Failed to start rewards setup: $e');
        }),
      );
    } else {
      setState(() {}); // Refresh to show next curriculum
    }
  }

  Future<void> _startRewardsSetup() async {
    // Check user mode — only show for child mode
    final profileService = ref.read(userProfileServiceProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      await _finishOnboarding();
      return;
    }

    final userMode = await profileService.getUserMode(uid);
    if (userMode != UserMode.child) {
      // Adult mode skips rewards setup entirely
      await _finishOnboarding();
      return;
    }

    setState(() => _phase = _ScreenPhase.rewardsSetup);
  }

  Future<void> _onRewardsResult(RewardSetupResult? result) async {
    if (result != null && result.rewards.isNotEmpty) {
      final rewardService = ref.read(rewardServiceProvider);
      for (final entry in result.rewards) {
        await rewardService.addReward(
          title: entry.title,
          description: entry.description,
          pointsThreshold: entry.pointsThreshold,
        );
      }
    }
    await _finishOnboarding();
  }

  List<int> _computeSuggestedThresholds() {
    final configsAsync = ref.read(allCurriculaConfigsProvider);
    final totalItems =
        configsAsync.whenOrNull(
          data: (configs) {
            var sum = 0;
            for (final id in _selected) {
              sum += configs[id]?.totalItems ?? 0;
            }
            return sum;
          },
        ) ??
        0;
    // Estimate daily pace from total items / 365 (default 1 year)
    final dailyPace = totalItems > 0 ? (totalItems / 365).ceil() : 5;
    return SuggestedThresholdsService.calculate(
      totalItems: totalItems,
      dailyPace: dailyPace,
    );
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
      appBar: AppBar(title: const AppBarTitle(text: 'Select Curricula')),
      body: switch (_phase) {
        _ScreenPhase.selection => _buildSelection(theme),
        _ScreenPhase.importing => _buildImporting(theme),
        _ScreenPhase.scopeSelection => _buildScopeSelection(theme),
        _ScreenPhase.learningProcessWizard => _buildLearningProcessWizard(theme),
        _ScreenPhase.bulkMark => _buildBulkMark(theme),
        _ScreenPhase.goalSetup => _buildGoalSetup(theme),
        _ScreenPhase.rewardsSetup => _buildRewardsSetup(theme),
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
    final doneCount = _curriculumStatuses.values
        .where((s) => s == _CurriculumStatus.done)
        .length;
    final fraction = _originalTotal > 0 ? doneCount / _originalTotal : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Importing curricula...', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            if (progress != null) ...[
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 16),
              Text(
                '$doneCount/$_originalTotal complete',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              // Per-curriculum progress indicators (AC7)
              for (final id in _selected)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          id.displayNameEn,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: LinearProgressIndicator(
                          value: switch (_curriculumStatuses[id]) {
                            _CurriculumStatus.done => 1.0,
                            _CurriculumStatus.failed => 1.0,
                            _CurriculumStatus.importing => null,
                            _ => 0.0,
                          },
                          color:
                              _curriculumStatuses[id] ==
                                  _CurriculumStatus.failed
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: switch (_curriculumStatuses[id]) {
                          _CurriculumStatus.done => Icon(
                            Icons.check_circle,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          _CurriculumStatus.failed => Icon(
                            Icons.error,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          _CurriculumStatus.importing => const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    ],
                  ),
                ),
            ] else ...[
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelection(ThemeData theme) {
    final curriculum = _scopeQueue[_scopeIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Set Learning Scope',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Choose which parts of ${curriculum.displayNameEn} to track, '
            'or skip to track everything.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            '${_scopeIndex + 1} of ${_scopeQueue.length}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ScopeSelectionScreen(curriculumId: curriculum),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onScopeSelectionDone,
                  child: const Text('Skip (Track All)'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _onScopeSelectionDone,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearningProcessWizard(ThemeData theme) {
    final curriculum = _wizardQueue[_wizardIndex];

    if (!_wizardLaunched) {
      _wizardLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final wizardService = ref.read(learningProcessWizardServiceProvider);
        final presets = await wizardService.getPresetsForCurriculum(curriculum);
        if (!mounted) return;

        final profileService = ref.read(userProfileServiceProvider);
        final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
        var isChildMode = false;
        if (uid != null) {
          final mode = await profileService.getUserMode(uid);
          isChildMode = mode == UserMode.child;
        }

        if (!mounted) return;
        final result = await Navigator.of(
          context,
        ).push<LearningProcessWizardResult>(
          MaterialPageRoute<LearningProcessWizardResult>(
            builder: (_) => LearningProcessWizardScreen(
              curriculumId: curriculum,
              presets: presets,
              isChildMode: isChildMode,
            ),
          ),
        );
        if (mounted) {
          _wizardLaunched = false;
          await _onWizardResult(result);
        }
      });
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Set up review schedule for ${curriculum.displayNameEn}',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_wizardIndex + 1} of ${_wizardQueue.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBulkMark(ThemeData theme) {
    final curriculum = _bulkMarkQueue[_bulkMarkIndex];

    if (!_bulkMarkLaunched) {
      _bulkMarkLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final result = await Navigator.of(context).push<BulkMarkResult>(
          MaterialPageRoute<BulkMarkResult>(
            builder: (_) => BulkMarkScreen(curriculumId: curriculum),
          ),
        );
        if (mounted) {
          _bulkMarkLaunched = false;
          await _onBulkMarkResult(result);
        }
      });
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mark prior completions for ${curriculum.displayNameEn}',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_bulkMarkIndex + 1} of ${_bulkMarkQueue.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  Widget _buildRewardsSetup(ThemeData theme) {
    final thresholds = _computeSuggestedThresholds();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set up mystery rewards',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add rewards your child can earn by learning!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<RewardSetupResult>(
                      MaterialPageRoute<RewardSetupResult>(
                        builder: (_) =>
                            RewardsSetupScreen(suggestedThresholds: thresholds),
                      ),
                    );
                if (mounted) {
                  await _onRewardsResult(result);
                }
              },
              child: const Text('Set Up Rewards'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _onRewardsResult(null),
              child: const Text('Skip'),
            ),
          ],
        ),
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
