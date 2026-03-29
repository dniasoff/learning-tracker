import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/curriculum_picker_step.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/program_selection_step.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/track_label_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAddTrackStep = 'add_track_step';
const _kAddTrackCurriculum = 'add_track_curriculum';
const _kAddTrackScope = 'add_track_scope';
const _kAddTrackProgram = 'add_track_program';
const _kAddTrackProgramName = 'add_track_program_name';
const _kAddTrackStudyDays = 'add_track_study_days';
const _kAddTrackLabel = 'add_track_label';

/// A standalone, reusable 8-step wizard for configuring a single learning track.
///
/// Can be embedded in onboarding or launched from settings.
class AddTrackFlow extends ConsumerStatefulWidget {
  const AddTrackFlow({
    required this.profileId,
    required this.isOnboarding,
    required this.isChildMode,
    this.onComplete,
    this.onCancel,
    super.key,
  });

  final int profileId;
  final bool isOnboarding;
  final bool isChildMode;
  final ValueChanged<AddTrackResult>? onComplete;
  final VoidCallback? onCancel;

  @override
  ConsumerState<AddTrackFlow> createState() => _AddTrackFlowState();
}

class _AddTrackFlowState extends ConsumerState<AddTrackFlow> {
  AddTrackState _state = const AddTrackState();
  late final PageController _pageController;
  Future<void>? _activationFuture;

  /// Ordered list of steps; program may be skipped dynamically.
  List<AddTrackStep> get _activeSteps {
    final steps = List<AddTrackStep>.from(AddTrackStep.values);
    // Auto-skip program step if no programs exist for curriculum
    if (_state.curriculumId != null &&
        !_hasProgramsForCurriculum(_state.curriculumId!)) {
      steps.remove(AddTrackStep.program);
    }
    return steps;
  }

  int get _currentIndex => _activeSteps.indexOf(_state.currentStep);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tryResumeState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _hasProgramsForCurriculum(CurriculumId curriculum) {
    // Programs exist for bavli (Daf Yomi, Oraysa) and mishnaBerurah (Dirshu)
    return curriculum == CurriculumId.bavli ||
        curriculum == CurriculumId.mishnaBerurah;
  }

  Future<void> _tryResumeState() async {
    final prefs = await SharedPreferences.getInstance();
    final stepIndex = prefs.getInt(_kAddTrackStep);
    if (stepIndex == null) return;

    final curriculumKey = prefs.getString(_kAddTrackCurriculum);
    final scopeJson = prefs.getString(_kAddTrackScope);
    final programId = prefs.getInt(_kAddTrackProgram);
    final programName = prefs.getString(_kAddTrackProgramName);
    final studyDaysJson = prefs.getString(_kAddTrackStudyDays);
    final label = prefs.getString(_kAddTrackLabel);

    CurriculumId? curriculum;
    if (curriculumKey != null) {
      curriculum = CurriculumId.values
          .where((c) => c.storageKey == curriculumKey)
          .firstOrNull;
    }

    List<ScopeEntry>? scopes;
    if (scopeJson != null) {
      final list = jsonDecode(scopeJson) as List<dynamic>;
      scopes = list
          .cast<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> e) => ScopeEntry(
              level: e['level'] as int,
              value: e['value'] as String,
            ),
          )
          .toList();
    }

    Map<int, String>? studyDays;
    if (studyDaysJson != null) {
      final map = jsonDecode(studyDaysJson) as Map<String, dynamic>;
      studyDays = map.map((k, v) => MapEntry(int.parse(k), v as String));
    }

    final step =
        AddTrackStep.values[stepIndex.clamp(0, AddTrackStep.values.length - 1)];

    setState(() {
      _state = _state.copyWith(
        currentStep: step,
        curriculumId: curriculum,
        scopeSelections: scopes,
        programId: programId,
        programName: programName,
        studyDays: studyDays,
        trackLabel: label,
      );
    });

    final targetIndex = _activeSteps.indexOf(step);
    if (targetIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(targetIndex);
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAddTrackStep, _state.currentStep.index);

    if (_state.curriculumId != null) {
      await prefs.setString(
        _kAddTrackCurriculum,
        _state.curriculumId!.storageKey,
      );
    }
    if (_state.scopeSelections != null) {
      await prefs.setString(
        _kAddTrackScope,
        jsonEncode(
          _state.scopeSelections!
              .map((s) => {'level': s.level, 'value': s.value})
              .toList(),
        ),
      );
    }
    if (_state.programId != null) {
      await prefs.setInt(_kAddTrackProgram, _state.programId!);
    }
    if (_state.programName != null) {
      await prefs.setString(_kAddTrackProgramName, _state.programName!);
    }
    if (_state.studyDays != null) {
      await prefs.setString(
        _kAddTrackStudyDays,
        jsonEncode(_state.studyDays!.map((k, v) => MapEntry(k.toString(), v))),
      );
    }
    if (_state.trackLabel != null) {
      await prefs.setString(_kAddTrackLabel, _state.trackLabel!);
    }
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kAddTrackStep,
      _kAddTrackCurriculum,
      _kAddTrackScope,
      _kAddTrackProgram,
      _kAddTrackProgramName,
      _kAddTrackStudyDays,
      _kAddTrackLabel,
    ]) {
      await prefs.remove(key);
    }
  }

  void _goToNextStep() {
    final currentIndex = _currentIndex;
    if (currentIndex < _activeSteps.length - 1) {
      final nextStep = _activeSteps[currentIndex + 1];
      setState(() {
        _state = _state.copyWith(currentStep: nextStep);
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _saveState();
    }
  }

  void _goToPreviousStep() {
    final currentIndex = _currentIndex;
    if (currentIndex > 0) {
      final prevStep = _activeSteps[currentIndex - 1];
      setState(() {
        _state = _state.copyWith(currentStep: prevStep);
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleExit();
    }
  }

  Future<void> _handleExit() async {
    final hasData = _state.curriculumId != null;
    if (hasData) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit Track Setup?'),
          content: const Text('Your progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
      if (shouldExit != true) return;
    }
    await _clearSavedState();
    widget.onCancel?.call();
  }

  void _onCurriculumSelected(CurriculumId curriculum) {
    // Fire-and-forget content activation in background (T3/AC-5)
    final service = ref.read(curriculumActivationServiceProvider);
    _activationFuture = service
        .activate(curriculum)
        .then((_) {
          if (mounted) {
            setState(() {
              _state = _state.copyWith(contentActivated: true);
            });
          }
        })
        .catchError((_) {
          // Silent fail — activation may already be done
          if (mounted) {
            setState(() {
              _state = _state.copyWith(contentActivated: true);
            });
          }
        });

    setState(() {
      _state = _state.copyWith(curriculumId: curriculum);
    });
    _goToNextStep();
  }

  void _onScopeComplete(List<ScopeEntry>? scopes) {
    setState(() {
      _state = _state.copyWith(scopeSelections: scopes);
    });
    _goToNextStep();
  }

  void _onProgramSelected(int? programId, String? programName) {
    // Auto-adjust scope when program is selected (T5/AC-6)
    // Programs like Daf Yomi cover all of Bavli — clear any scope narrowing
    var adjustedScope = _state.scopeSelections;
    if (programId != null) {
      adjustedScope = null; // Program = full scope
    }

    setState(() {
      _state = _state.copyWith(
        programId: programId,
        programName: programName,
        scopeSelections: adjustedScope,
      );
    });
    _goToNextStep();
  }

  void _onStudyDaysComplete(Map<int, String> studyDays) {
    setState(() {
      _state = _state.copyWith(studyDays: studyDays);
    });
    _goToNextStep();
  }

  void _onChazaraComplete(LearningProcessWizardResult? result) {
    setState(() {
      _state = _state.copyWith(wizardResult: result);
    });
    _goToNextStep();
  }

  void _onGoalComplete(GoalFormResult? result) {
    setState(() {
      _state = _state.copyWith(goalResult: result);
    });
    _goToNextStep();
  }

  void _onTrackLabelComplete(String label) {
    setState(() {
      _state = _state.copyWith(trackLabel: label);
    });
    _goToNextStep();
  }

  Future<void> _onBulkMarkComplete(BulkMarkResult? result) async {
    setState(() {
      _state = _state.copyWith(bulkMarkResult: result);
    });
    await _finishFlow();
  }

  Future<void> _finishFlow() async {
    final result = AddTrackResult(
      curriculumId: _state.curriculumId!,
      label: _state.trackLabel ?? _state.curriculumId!.displayNameHe,
      programId: _state.programId,
      programName: _state.programName,
      scopeSelections: _state.scopeSelections,
      studyDays: _state.studyDays ?? kDefaultStudyDays,
      wizardResult: _state.wizardResult,
      goalResult: _state.goalResult,
      bulkMarkResult: _state.bulkMarkResult,
    );

    // Persist track to database — clear state only on success (FIX-5)
    try {
      final creationService = ref.read(trackCreationServiceProvider);
      await creationService.createTrack(
        result: result,
        profileId: widget.profileId,
      );
      await _clearSavedState();
      widget.onComplete?.call(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save track. Please try again.'),
          action: SnackBarAction(label: 'Retry', onPressed: _finishFlow),
        ),
      );
    }
  }

  String _getSmartDefault() {
    if (_state.programName != null) return _state.programName!;
    if (_state.scopeSelections != null && _state.scopeSelections!.isNotEmpty) {
      return _state.scopeSelections!.last.value;
    }
    return _state.curriculumId?.displayNameHe ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToPreviousStep();
      },
      child: Column(
        children: [
          // Progress indicator
          if (steps.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / steps.length,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),

          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: steps.map((step) => _buildStep(step)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(AddTrackStep step) {
    // Guard: steps after curriculum require curriculumId to be set.
    // PageView pre-builds all pages, so we show a placeholder until
    // the user selects a curriculum on step 1.
    if (step != AddTrackStep.curriculum && _state.curriculumId == null) {
      return const SizedBox.shrink();
    }

    return switch (step) {
      AddTrackStep.curriculum => CurriculumPickerStep(
        onSelected: _onCurriculumSelected,
        isOnboarding: widget.isOnboarding,
      ),
      AddTrackStep.scope => _buildScopeStep(),
      AddTrackStep.program => ProgramSelectionStep(
        curriculumId: _state.curriculumId!,
        onSelected: _onProgramSelected,
      ),
      AddTrackStep.studyDays => _buildStudyDaysStep(),
      AddTrackStep.chazaraSetup => _buildChazaraStep(),
      AddTrackStep.goal => _buildGoalStep(),
      AddTrackStep.trackName => TrackLabelStep(
        defaultLabel: _getSmartDefault(),
        onComplete: _onTrackLabelComplete,
      ),
      AddTrackStep.bulkMark => _buildBulkMarkStep(),
    };
  }

  Widget _buildScopeStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    // Show spinner if content activation not yet complete (T4/AC-5)
    if (!_state.contentActivated && _activationFuture != null) {
      return FutureBuilder<void>(
        future: _activationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing content...'),
                ],
              ),
            );
          }
          return _ScopeStepAdapter(
            curriculumId: _state.curriculumId!,
            onComplete: _onScopeComplete,
          );
        },
      );
    }
    return _ScopeStepAdapter(
      curriculumId: _state.curriculumId!,
      onComplete: _onScopeComplete,
    );
  }

  Widget _buildStudyDaysStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    return _StudyDaysStepAdapter(
      curriculumId: _state.curriculumId!,
      onComplete: _onStudyDaysComplete,
      onSkip: () =>
          _onStudyDaysComplete(Map<int, String>.from(kDefaultStudyDays)),
    );
  }

  Widget _buildChazaraStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    return _ChazaraStepAdapter(
      curriculumId: _state.curriculumId!,
      isChildMode: widget.isChildMode,
      onComplete: _onChazaraComplete,
    );
  }

  Widget _buildGoalStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    return _GoalStepAdapter(
      curriculumId: _state.curriculumId!,
      onComplete: _onGoalComplete,
      onSkip: () => _onGoalComplete(null),
    );
  }

  Widget _buildBulkMarkStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    return _BulkMarkStepAdapter(
      curriculumId: _state.curriculumId!,
      onComplete: _onBulkMarkComplete,
      onSkip: () => _onBulkMarkComplete(null),
    );
  }
}

// ── Adapter Widgets ──────────────────────────────────────────────────────────

class _ScopeStepAdapter extends ConsumerWidget {
  const _ScopeStepAdapter({
    required this.curriculumId,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final ValueChanged<List<ScopeEntry>?> onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Scope',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which parts of ${curriculumId.displayNameHe} to track, or select all.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => onComplete(null), // null = all
            child: const Text('Track All'),
          ),
        ],
      ),
    );
  }
}

class _StudyDaysStepAdapter extends StatelessWidget {
  const _StudyDaysStepAdapter({
    required this.curriculumId,
    required this.onComplete,
    required this.onSkip,
  });

  final CurriculumId curriculumId;
  final ValueChanged<Map<int, String>> onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final days = Map<int, String>.from(kDefaultStudyDays);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Study Days',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Which days do you learn?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final dayNum = i + 1;
                  final isStudy = days[dayNum] == 'study';
                  return FilterChip(
                    label: Text(dayNames[i]),
                    selected: isStudy,
                    onSelected: (selected) {
                      setState(() {
                        days[dayNum] = selected ? 'study' : 'review';
                      });
                    },
                  );
                }),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSkip,
                      child: const Text('Use Defaults'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onComplete(Map.from(days)),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChazaraStepAdapter extends StatelessWidget {
  const _ChazaraStepAdapter({
    required this.curriculumId,
    required this.isChildMode,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final bool isChildMode;
  final ValueChanged<LearningProcessWizardResult?> onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Configure Review', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Set up your review (חזרה) schedule.',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              Navigator.push<LearningProcessWizardResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => LearningProcessWizardScreen(
                    curriculumId: curriculumId,
                    presets: const [],
                    isChildMode: isChildMode,
                  ),
                ),
              ).then((LearningProcessWizardResult? result) {
                onComplete(result);
              });
            },
            child: const Text('Configure חזרה'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => onComplete(null),
            child: const Text('Skip (no review)'),
          ),
        ],
      ),
    );
  }
}

class _GoalStepAdapter extends StatelessWidget {
  const _GoalStepAdapter({
    required this.curriculumId,
    required this.onComplete,
    required this.onSkip,
  });

  final CurriculumId curriculumId;
  final ValueChanged<GoalFormResult?> onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set a Goal', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Set a pace or deadline goal, or skip for now.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    // Navigate to full GoalSetupScreen
                    Navigator.push<GoalFormResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GoalSetupScreen(curriculumId: curriculumId),
                      ),
                    ).then((result) {
                      if (result != null) onComplete(result);
                    });
                  },
                  child: const Text('Set Goal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulkMarkStepAdapter extends StatelessWidget {
  const _BulkMarkStepAdapter({
    required this.curriculumId,
    required this.onComplete,
    required this.onSkip,
  });

  final CurriculumId curriculumId;
  final ValueChanged<BulkMarkResult?> onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mark Prior Learning',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Already completed some items? Mark them now so the app knows your progress.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.push<BulkMarkResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BulkMarkScreen(curriculumId: curriculumId),
                      ),
                    ).then((result) {
                      onComplete(result);
                    });
                  },
                  child: const Text('Mark Completions'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
