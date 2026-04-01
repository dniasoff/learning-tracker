import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
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

/// Day labels in Jewish week order (Sunday first, Shabbos last).
const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Shabbos'];

/// ISO day numbers in Jewish week order.
const _dayNumbers = [7, 1, 2, 3, 4, 5, 6];

/// A standalone, reusable 8-step wizard for configuring a single learning track.
///
/// Can be embedded in onboarding or launched from settings.
/// Program-aware: auto-fills/skips steps based on selected program.
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

  /// Whether a program was selected (vs self-paced).
  bool get _isProgramTrack => _state.programId != null;

  /// Whether the selected program defines review/chazara stages.
  bool get _programHasChazara {
    final program = _state.selectedProgram;
    if (program is! LearningProgram) return false;
    try {
      final stages = jsonDecode(program.stagesConfig) as List<dynamic>;
      return stages.any(
        (s) => (s as Map<String, dynamic>)['stage'].toString() != 'learn',
      );
    } catch (_) {
      return false;
    }
  }

  /// Active steps — program-aware skipping.
  List<AddTrackStep> get _activeSteps {
    final steps = <AddTrackStep>[AddTrackStep.curriculum];

    // Program — auto-skip if no programs exist for curriculum
    if (_state.curriculumId == null || _curriculumHasPrograms) {
      steps.add(AddTrackStep.program);
    }

    // Scope — skip if program selected (program defines scope)
    if (!_isProgramTrack) {
      steps.add(AddTrackStep.scope);
    }

    // Study days — skip for program tracks (all days are study days)
    if (!_isProgramTrack) {
      steps.add(AddTrackStep.studyDays);
    }

    // Chazara — always shown (behavior varies: ask/show/offer)
    steps.add(AddTrackStep.chazaraSetup);

    // Goal — skip for program tracks
    if (!_isProgramTrack) {
      steps.add(AddTrackStep.goal);
    }

    // Track name — always shown
    steps.add(AddTrackStep.trackName);

    // Bulk mark / starting position — always shown
    steps.add(AddTrackStep.bulkMark);

    return steps;
  }

  /// Whether the selected curriculum has programs in the DB.
  bool get _curriculumHasPrograms {
    // Curricula with programs: bavli (4 programs), yerushalmi (1),
    // mishna_berurah (1), mussar (1), mishnayos (1), nach (1)
    // Simpler: check if NOT in the list with zero programs
    // chumash, torah, tanach have no programs
    if (_state.curriculumId == null) return true;
    return _state.curriculumId != CurriculumId.chumash &&
        _state.curriculumId != CurriculumId.torah &&
        _state.curriculumId != CurriculumId.tanach;
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
            (e) => ScopeEntry(
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

    // Reload program from DB if we had one
    LearningProgram? selectedProgram;
    if (programId != null) {
      final contentDb = ref.read(contentDatabaseProvider);
      selectedProgram = await contentDb.contentLearningProgramDao
          .getProgramById(programId);
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
        selectedProgram: selectedProgram,
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

  // ── Callbacks ──────────────────────────────────────────────────────────────

  void _onCurriculumSelected(CurriculumId curriculum) {
    final service = ref.read(curriculumActivationServiceProvider);
    _activationFuture = service
        .activateForProfile(curriculum, widget.profileId)
        .then((_) {
          if (mounted) {
            setState(() => _state = _state.copyWith(contentActivated: true));
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() => _state = _state.copyWith(contentActivated: true));
          }
        });

    setState(() => _state = _state.copyWith(curriculumId: curriculum));
    _goToNextStep();
  }

  void _onProgramSelected(
    int? programId,
    String? programName,
    LearningProgram? program,
  ) {
    setState(() {
      _state = _state.copyWith(
        programId: programId,
        programName: programName,
        selectedProgram: program,
        scopeSelections: programId != null ? null : _state.scopeSelections,
      );
    });
    _goToNextStep();
  }

  void _onScopeComplete(List<ScopeEntry>? scopes) {
    setState(() => _state = _state.copyWith(scopeSelections: scopes));
    _goToNextStep();
  }

  void _onStudyDaysComplete(Map<int, String> studyDays) {
    setState(() => _state = _state.copyWith(studyDays: studyDays));
    _goToNextStep();
  }

  void _onChazaraComplete(LearningProcessWizardResult? result) {
    setState(() => _state = _state.copyWith(wizardResult: result));
    _goToNextStep();
  }

  void _onGoalComplete(GoalFormResult? result) {
    setState(() => _state = _state.copyWith(goalResult: result));
    _goToNextStep();
  }

  void _onTrackLabelComplete(String label) {
    setState(() => _state = _state.copyWith(trackLabel: label));
    _goToNextStep();
  }

  Future<void> _onBulkMarkComplete(BulkMarkResult? result) async {
    setState(() => _state = _state.copyWith(bulkMarkResult: result));
    await _finishFlow();
  }

  Future<void> _onStartingPositionComplete(String? startingRef) async {
    setState(() => _state = _state.copyWith(startingRef: startingRef));
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
      startingRef: _state.startingRef,
    );

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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToPreviousStep();
      },
      child: SafeArea(
        top: false,
        child: Column(
          children: [
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
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: steps.map(_buildStep).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(AddTrackStep step) {
    if (step != AddTrackStep.curriculum && _state.curriculumId == null) {
      return const SizedBox.shrink();
    }

    return switch (step) {
      AddTrackStep.curriculum => CurriculumPickerStep(
        onSelected: _onCurriculumSelected,
        isOnboarding: widget.isOnboarding,
      ),
      AddTrackStep.program => ProgramSelectionStep(
        curriculumId: _state.curriculumId!,
        onSelected: _onProgramSelected,
      ),
      AddTrackStep.scope => _buildScopeStep(),
      AddTrackStep.studyDays => _buildStudyDaysStep(),
      AddTrackStep.chazaraSetup => _buildChazaraStep(),
      AddTrackStep.goal => _buildGoalStep(),
      AddTrackStep.trackName => TrackLabelStep(
        defaultLabel: _getSmartDefault(),
        onComplete: _onTrackLabelComplete,
      ),
      AddTrackStep.bulkMark => _buildScreen8(),
    };
  }

  // ── Step Builders ──────────────────────────────────────────────────────────

  Widget _buildScopeStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
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
          return _ScopeStepContent(
            curriculumId: _state.curriculumId!,
            onComplete: _onScopeComplete,
          );
        },
      );
    }
    return _ScopeStepContent(
      curriculumId: _state.curriculumId!,
      onComplete: _onScopeComplete,
    );
  }

  Widget _buildStudyDaysStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

    // Program mode: auto-fill read-only
    if (_isProgramTrack) {
      return _StudyDaysReadOnly(
        programName: _state.programName ?? '',
        onContinue: () =>
            _onStudyDaysComplete(Map<int, String>.from(kDefaultStudyDays)),
      );
    }

    // Self-paced: editable vertical list
    return _StudyDaysEditable(
      onComplete: _onStudyDaysComplete,
      onSkip: () =>
          _onStudyDaysComplete(Map<int, String>.from(kDefaultStudyDays)),
    );
  }

  Widget _buildChazaraStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    // Program with DEFINED chazara → show read-only
    if (_isProgramTrack && _programHasChazara) {
      final program = _state.selectedProgram as LearningProgram;
      List<dynamic> stages;
      try {
        stages = jsonDecode(program.stagesConfig) as List<dynamic>;
      } catch (_) {
        stages = [];
      }
      final chazaraStages = stages
          .where(
            (s) => (s as Map<String, dynamic>)['stage'].toString() != 'learn',
          )
          .toList();

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Review Schedule', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Review stages set by ${_state.programName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ...chazaraStages.map((s) {
              final stage = s as Map<String, dynamic>;
              final name = stage['stage'].toString().replaceAll('_', ' ');
              final delay = stage['delay_days'];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(name),
                  subtitle: delay != null ? Text('After $delay days') : null,
                ),
              );
            }),
            const Spacer(),
            FilledButton(
              onPressed: () => _onChazaraComplete(null),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }

    // Program with OPEN chazara → offer optional
    if (_isProgramTrack && !_programHasChazara) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Review?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${_state.programName} doesn\'t include a review schedule. '
              'Would you like to add one?',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.push<LearningProcessWizardResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LearningProcessWizardScreen(
                      curriculumId: _state.curriculumId!,
                      presets: const [],
                      isChildMode: widget.isChildMode,
                      skipChooseMethod: true,
                    ),
                  ),
                ).then((result) => _onChazaraComplete(result));
              },
              child: const Text('Configure חזרה'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _onChazaraComplete(null),
              child: const Text('Skip (no review)'),
            ),
          ],
        ),
      );
    }

    // Self-paced → ask (skip directly to custom builder)
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
                    curriculumId: _state.curriculumId!,
                    presets: const [],
                    isChildMode: widget.isChildMode,
                    skipChooseMethod: true,
                  ),
                ),
              ).then((result) => _onChazaraComplete(result));
            },
            child: const Text('Configure חזרה'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _onChazaraComplete(null),
            child: const Text('Skip (no review)'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
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
                  onPressed: () => _onGoalComplete(null),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.push<GoalFormResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GoalSetupScreen(curriculumId: _state.curriculumId!),
                      ),
                    ).then((result) {
                      if (result != null) _onGoalComplete(result);
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

  /// Screen 8: Bulk Mark (self-paced) or Starting Position (program).
  Widget _buildScreen8() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

    // Program mode: starting position
    if (_isProgramTrack) {
      return _StartingPositionStep(
        programName: _state.programName ?? '',
        onComplete: _onStartingPositionComplete,
      );
    }

    // Self-paced: bulk mark
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
                  onPressed: () => _onBulkMarkComplete(null),
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
                        builder: (_) => BulkMarkScreen(
                          curriculumId: _state.curriculumId!,
                          scopeConstraints: _state.scopeSelections,
                        ),
                      ),
                    ).then(_onBulkMarkComplete);
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

// ── Adapter Widgets ──────────────────────────────────────────────────────────

/// Inline scope selector — pick "Track All" or drill into hierarchy to
/// multi-select sections at a chosen level.
class _ScopeStepContent extends ConsumerStatefulWidget {
  const _ScopeStepContent({
    required this.curriculumId,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final ValueChanged<List<ScopeEntry>?> onComplete;

  @override
  ConsumerState<_ScopeStepContent> createState() => _ScopeStepContentState();
}

class _ScopeStepContentState extends ConsumerState<_ScopeStepContent> {
  /// null = initial choice screen, non-null = selecting values at this level.
  int? _selectedLevel;
  final Set<String> _selectedValues = {};

  CurriculumHierarchyDefaults get _hierarchy =>
      CurriculumDefaults.hierarchyConfigs[widget.curriculumId]!;

  List<String> get _levelLabels => [
        _hierarchy.level1Label,
        if (_hierarchy.level2Label != null) _hierarchy.level2Label!,
        if (_hierarchy.level3Label != null) _hierarchy.level3Label!,
        if (_hierarchy.level4Label != null) _hierarchy.level4Label!,
      ];

  String _labelForLevel(int level) {
    return level <= _levelLabels.length ? _levelLabels[level - 1] : 'Level $level';
  }

  String? _getItemLevel(ContentItem item, int level) {
    return switch (level) {
      1 => item.level1,
      2 => item.level2,
      3 => item.level3,
      4 => item.level4,
      _ => null,
    };
  }

  List<String> _distinctValuesAtLevel(List<ContentItem> items, int level) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final value = _getItemLevel(item, level);
      if (value != null && seen.add(value)) result.add(value);
    }
    return result;
  }

  void _done() {
    if (_selectedLevel == null || _selectedValues.isEmpty) {
      widget.onComplete(null);
    } else {
      widget.onComplete(
        _selectedValues
            .map((v) => ScopeEntry(level: _selectedLevel!, value: v))
            .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(curriculumContentProvider(widget.curriculumId));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'All of it, or just a section?',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            widget.curriculumId.displayNameHe,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading content: $e')),
              data: (items) => _selectedLevel == null
                  ? _buildInitialChoice(items)
                  : _buildValueSelection(items),
            ),
          ),
        ],
      ),
    );
  }

  /// Initial screen: "Learn All" + level drill-down options.
  Widget _buildInitialChoice(List<ContentItem> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => widget.onComplete(null),
          icon: const Icon(Icons.select_all),
          label: const Text('Learn All'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Or choose specific sections:',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _hierarchy.maxLevels - 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final level = index + 1;
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text('Choose a ${_labelForLevel(level)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  _selectedLevel = level;
                  _selectedValues.clear();
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Multi-select values at the chosen level.
  Widget _buildValueSelection(List<ContentItem> items) {
    final values = _distinctValuesAtLevel(items, _selectedLevel!);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedLevel = null;
                _selectedValues.clear();
              }),
            ),
            const SizedBox(width: 8),
            Text(
              'Select ${_labelForLevel(_selectedLevel!)}',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedValues.length == values.length) {
                    _selectedValues.clear();
                  } else {
                    _selectedValues.addAll(values);
                  }
                });
              },
              child: Text(
                _selectedValues.length == values.length
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        if (_selectedValues.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '${_selectedValues.length} of ${values.length} selected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _selectedValues
                  .map(
                    (v) => Chip(
                      label: Text(v, style: theme.textTheme.labelSmall),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _selectedValues.remove(v)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              final isSelected = _selectedValues.contains(value);
              return CheckboxListTile(
                title: Text(value),
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      _selectedValues.add(value);
                    } else {
                      _selectedValues.remove(value);
                    }
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _selectedValues.isNotEmpty ? _done : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            _selectedValues.isEmpty
                ? 'Select at least one'
                : 'Continue with ${_selectedValues.length} selected',
          ),
        ),
      ],
    );
  }
}

/// Study days — vertical layout, all 7 active by default, "Shabbos" label.
class _StudyDaysEditable extends StatefulWidget {
  const _StudyDaysEditable({required this.onComplete, required this.onSkip});

  final ValueChanged<Map<int, String>> onComplete;
  final VoidCallback onSkip;

  @override
  State<_StudyDaysEditable> createState() => _StudyDaysEditableState();
}

class _StudyDaysEditableState extends State<_StudyDaysEditable> {
  late final Map<int, String> _days;

  @override
  void initState() {
    super.initState();
    _days = Map<int, String>.from(kDefaultStudyDays);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Study Days', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Which days do you learn?', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final dayNum = _dayNumbers[index];
                final isActive = _days[dayNum] == 'study';
                return SwitchListTile(
                  title: Text(
                    _dayLabels[index],
                    style: theme.textTheme.bodyLarge,
                  ),
                  value: isActive,
                  onChanged: (v) {
                    setState(() => _days[dayNum] = v ? 'study' : 'review');
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  child: const Text('Use Defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onComplete(Map.from(_days)),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Study days — read-only display for program tracks.
class _StudyDaysReadOnly extends StatelessWidget {
  const _StudyDaysReadOnly({
    required this.programName,
    required this.onContinue,
  });

  final String programName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Study Days', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Study days set by $programName',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _dayLabels[index],
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                );
              },
            ),
          ),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
        ],
      ),
    );
  }
}

/// Starting position step for program tracks (Screen 8 program mode).
///
/// Allows users to offset the starting position by +/- 30 days from today.
class _StartingPositionStep extends StatefulWidget {
  const _StartingPositionStep({
    required this.programName,
    required this.onComplete,
  });

  final String programName;
  final ValueChanged<String?> onComplete;

  @override
  State<_StartingPositionStep> createState() => _StartingPositionStepState();
}

class _StartingPositionStepState extends State<_StartingPositionStep> {
  int _dayOffset = 0;

  String get _offsetLabel {
    if (_dayOffset == 0) return "Today's position";
    if (_dayOffset > 0) return '$_dayOffset ${_dayOffset == 1 ? 'day' : 'days'} ahead';
    return '${_dayOffset.abs()} ${_dayOffset.abs() == 1 ? 'day' : 'days'} behind';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Starting Position', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Where are you in ${widget.programName}?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _offsetLabel,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adjust if you started earlier or later',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '-30',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _dayOffset.toDouble(),
                          min: -30,
                          max: 30,
                          divisions: 60,
                          label: _offsetLabel,
                          onChanged: (v) =>
                              setState(() => _dayOffset = v.round()),
                        ),
                      ),
                      Text(
                        '+30',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (_dayOffset != 0)
                    TextButton(
                      onPressed: () => setState(() => _dayOffset = 0),
                      child: const Text('Reset to today'),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => widget.onComplete(
              _dayOffset != 0 ? 'offset:$_dayOffset' : null,
            ),
            child: const Text('Start Here'),
          ),
        ],
      ),
    );
  }
}
