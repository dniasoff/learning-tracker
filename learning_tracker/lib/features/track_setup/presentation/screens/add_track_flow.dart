import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
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
  bool _isAnimating = false;
  bool _pendingAdvance = false;

  /// Whether a program was selected (vs self-paced).
  bool get _isProgramTrack => _state.programId != null;

  /// Whether the selected program defines review/chazara stages.
  bool get _programHasChazara {
    final program = _state.selectedProgram;
    if (program is! LearningProgramData) return false;
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

    // Program — always included. ProgramSelectionStep handles the empty
    // case by auto-dismissing when no programs exist for the curriculum.
    // This avoids hardcoding which curricula have programs.
    steps.add(AddTrackStep.program);

    // Scope — skip if program selected (program defines scope)
    if (!_isProgramTrack) {
      steps.add(AddTrackStep.scope);
    }

    // Study days — skip for program tracks (all days, not user-configurable).
    if (!_isProgramTrack) {
      steps.add(AddTrackStep.studyDays);
    }

    // Chazara — always shown (behavior varies: ask/show/offer)
    steps.add(AddTrackStep.chazaraSetup);

    // Goal — skip for program tracks (goal is always "finish the program")
    if (!_isProgramTrack) {
      steps.add(AddTrackStep.goal);
    }

    // Track name — always shown. Program: auto-fill from program name.
    steps.add(AddTrackStep.trackName);

    // Bulk mark / starting position — always shown
    steps.add(AddTrackStep.bulkMark);

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
    LearningProgramData? selectedProgram;
    if (programId != null) {
      selectedProgram = LearningProgramRepository.instance
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
    // If a previous animation is in progress (e.g. an auto-skip fired during
    // the curriculum→program transition), queue the advance and run it after
    // the current animation completes. Otherwise the call would be dropped
    // and the user would be stuck on the auto-skipped (blank) step.
    if (_isAnimating) {
      _pendingAdvance = true;
      return;
    }
    final currentIndex = _currentIndex;
    if (currentIndex < _activeSteps.length - 1) {
      final nextStep = _activeSteps[currentIndex + 1];
      setState(() {
        _state = _state.copyWith(currentStep: nextStep);
      });
      _isAnimating = true;
      _pageController
          .nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            _isAnimating = false;
            if (_pendingAdvance && mounted) {
              _pendingAdvance = false;
              _goToNextStep();
            }
          });
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
    LearningProgramData? program,
  ) {
    setState(() {
      _state = _state.copyWith(
        programId: programId,
        programName: programName,
        selectedProgram: program,
        scopeSelections: programId != null ? null : _state.scopeSelections,
        // Auto-fill study days for program tracks (step is skipped).
        studyDays: programId != null
            ? Map<int, String>.from(kDefaultStudyDays)
            : _state.studyDays,
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
        child: Column(
          children: [
            if (steps.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
      final program = _state.selectedProgram as LearningProgramData;
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

    // Program with OPEN chazara → offer optional inline setup
    // Self-paced → inline setup
    // Both paths use _ChazaraInlineSetup; differ only in header copy.
    final headerTitle = _isProgramTrack
        ? 'Add Review?'
        : 'How do you want to review?';
    final headerSubtitle = _isProgramTrack
        ? '${_state.programName} doesn\'t include a review schedule. '
              'Set one up now or skip.'
        : 'Pick a preset or build your own חזרה schedule.';

    return _ChazaraInlineSetup(
      curriculumId: _state.curriculumId!,
      headerTitle: headerTitle,
      headerSubtitle: headerSubtitle,
      onComplete: _onChazaraComplete,
    );
  }

  Widget _buildGoalStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "What's your pace or deadline?",
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Set a goal, or skip for now.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GoalSetupForm(
            curriculumId: _state.curriculumId!,
            submitLabel: 'Continue',
            onComplete: _onGoalComplete,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextButton(
            onPressed: () => _onGoalComplete(null),
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }

  /// Screen 8: Bulk Mark (self-paced) or Starting Position (program).
  Widget _buildScreen8() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

    // Program mode: starting position
    if (_isProgramTrack) {
      return _StartingPositionStep(
        programName: _state.programName ?? '',
        curriculumId: _state.curriculumId!,
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

/// Hierarchical scope selector — drill down through the content tree
/// (e.g. Seder → Masechta → Perek) and select at any level.
///
/// Selecting at a higher level implicitly includes all children.
/// Auto-skips levels with only one option (DNI-202).
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
  /// Breadcrumb path: list of (level, value) pairs representing drill-down.
  final List<ScopeEntry> _breadcrumbs = [];

  /// Selected scope entries — can be at different levels.
  final List<ScopeEntry> _selections = [];

  bool _didAutoSkip = false;

  CurriculumHierarchyDefaults get _hierarchy =>
      CurriculumDefaults.hierarchyConfigs[widget.curriculumId]!;

  List<String> get _levelLabels => [
    _hierarchy.level1Label,
    if (_hierarchy.level2Label != null) _hierarchy.level2Label!,
    if (_hierarchy.level3Label != null) _hierarchy.level3Label!,
    if (_hierarchy.level4Label != null) _hierarchy.level4Label!,
  ];

  /// Current drill-down depth (0 = top level showing level 1 items).
  int get _currentLevel =>
      _breadcrumbs.isEmpty ? 1 : _breadcrumbs.last.level + 1;

  /// Max selectable level (exclude leaf level — no "By Daf/Amud").
  int get _maxSelectableLevel => _hierarchy.maxLevels - 1;

  String _labelForLevel(int level) {
    return level <= _levelLabels.length
        ? _levelLabels[level - 1]
        : 'Level $level';
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

  /// Get distinct values at the current level, filtered by breadcrumb ancestors.
  List<String> _valuesAtCurrentLevel(List<ContentItem> items) {
    var filtered = items;
    // Apply breadcrumb filters
    for (final crumb in _breadcrumbs) {
      filtered = filtered.where((item) {
        return _getItemLevel(item, crumb.level) == crumb.value;
      }).toList();
    }
    final seen = <String>{};
    final result = <String>[];
    for (final item in filtered) {
      final value = _getItemLevel(item, _currentLevel);
      if (value != null && seen.add(value)) result.add(value);
    }
    return result;
  }

  /// Whether a value at the current level is selected (directly or via ancestor).
  bool _isSelected(String value) {
    // Directly selected at this level
    if (_selections.any((s) => s.level == _currentLevel && s.value == value)) {
      return true;
    }
    // Implicitly selected via ancestor breadcrumb selection
    for (final crumb in _breadcrumbs) {
      if (_selections.any(
        (s) => s.level == crumb.level && s.value == crumb.value,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Whether a value is directly (not implicitly) selected.
  bool _isDirectlySelected(String value) {
    return _selections.any((s) => s.level == _currentLevel && s.value == value);
  }

  void _toggleSelection(String value) {
    setState(() {
      final existing = _selections.indexWhere(
        (s) => s.level == _currentLevel && s.value == value,
      );
      if (existing >= 0) {
        _selections.removeAt(existing);
      } else {
        // Remove any child selections that would be redundant
        _selections.removeWhere((s) => s.level > _currentLevel);
        _selections.add(ScopeEntry(level: _currentLevel, value: value));
      }
    });
  }

  void _drillInto(String value, List<ContentItem> items) {
    final nextLevel = _currentLevel + 1;
    if (nextLevel > _maxSelectableLevel) return;

    setState(() {
      _breadcrumbs.add(ScopeEntry(level: _currentLevel, value: value));
    });

    // Auto-skip levels with only one option
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nextValues = _valuesAtCurrentLevel(items);
      if (nextValues.length == 1 && _currentLevel < _maxSelectableLevel) {
        _drillInto(nextValues.first, items);
      }
    });
  }

  void _goBack() {
    setState(() {
      if (_breadcrumbs.isNotEmpty) {
        _breadcrumbs.removeLast();
      }
    });
  }

  void _done() {
    if (_selections.isEmpty) {
      widget.onComplete(null);
    } else {
      widget.onComplete(List.of(_selections));
    }
  }

  int get _totalSelectionCount => _selections.length;

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );
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
              error: (e, _) {
                // No bundled content for this curriculum — auto-skip scope
                // (treat as "learn all") per DNI-180: "Skip = all".
                if (!_didAutoSkip) {
                  _didAutoSkip = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onComplete(null);
                  });
                }
                return const Center(child: CircularProgressIndicator());
              },
              data: (items) {
                if (items.isEmpty) {
                  // Empty content — auto-skip scope (treat as "learn all").
                  if (!_didAutoSkip) {
                    _didAutoSkip = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onComplete(null);
                    });
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                return _breadcrumbs.isEmpty && _selections.isEmpty
                    ? _buildTopLevel(items)
                    : _buildHierarchyView(items);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Top-level: "Learn All" + list of level 1 items to drill into or select.
  Widget _buildTopLevel(List<ContentItem> items) {
    final theme = Theme.of(context);
    final values = _valuesAtCurrentLevel(items);

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
          'Or choose by ${_labelForLevel(1)}:',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              final canDrillDeeper = _currentLevel < _maxSelectableLevel;
              return _HierarchyTile(
                title: value,
                isSelected: _isDirectlySelected(value),
                canDrill: canDrillDeeper,
                onCheck: () => _toggleSelection(value),
                onDrill: canDrillDeeper ? () => _drillInto(value, items) : null,
              );
            },
          ),
        ),
        if (_selections.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _done,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('Continue with $_totalSelectionCount selected'),
          ),
        ],
      ],
    );
  }

  /// Drill-down view with breadcrumbs and item list.
  Widget _buildHierarchyView(List<ContentItem> items) {
    final theme = Theme.of(context);
    final values = _valuesAtCurrentLevel(items);
    final canDrillDeeper = _currentLevel < _maxSelectableLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumb trail
        _buildBreadcrumbs(theme),
        const SizedBox(height: 8),
        // Selection chips
        if (_selections.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _selections
                  .map(
                    (s) => Chip(
                      label: Text(
                        '${_labelForLevel(s.level)}: ${s.value}',
                        style: theme.textTheme.labelSmall,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _selections.remove(s)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        // Item list
        Expanded(
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              return _HierarchyTile(
                title: value,
                isSelected: _isSelected(value),
                isImplicit: _isSelected(value) && !_isDirectlySelected(value),
                canDrill: canDrillDeeper,
                onCheck: () => _toggleSelection(value),
                onDrill: canDrillDeeper ? () => _drillInto(value, items) : null,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _selections.isNotEmpty ? _done : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            _selections.isEmpty
                ? 'Select at least one'
                : 'Continue with $_totalSelectionCount selected',
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
          tooltip: 'Back',
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _breadcrumbs.clear()),
                  child: Text(
                    widget.curriculumId.displayNameHe,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (var i = 0; i < _breadcrumbs.length; i++) ...[
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  InkWell(
                    onTap: i < _breadcrumbs.length - 1
                        ? () => setState(() {
                            _breadcrumbs.removeRange(
                              i + 1,
                              _breadcrumbs.length,
                            );
                          })
                        : null,
                    child: Text(
                      _breadcrumbs[i].value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: i < _breadcrumbs.length - 1
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: i == _breadcrumbs.length - 1
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single row in the hierarchy: checkbox + title + optional drill arrow.
class _HierarchyTile extends StatelessWidget {
  const _HierarchyTile({
    required this.title,
    required this.isSelected,
    required this.canDrill,
    required this.onCheck,
    this.onDrill,
    this.isImplicit = false,
  });

  final String title;
  final bool isSelected;
  final bool isImplicit;
  final bool canDrill;
  final VoidCallback onCheck;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: isImplicit ? null : (_) => onCheck(),
      ),
      title: Text(
        title,
        style: isImplicit
            ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
      ),
      trailing: canDrill
          ? IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onDrill,
              tooltip: 'Show contents',
            )
          : null,
      onTap: onCheck,
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
/// Lets users pick their current position by content (e.g. which daf/page
/// they are up to) using a two-level drill-down: container → leaf item.
class _StartingPositionStep extends ConsumerStatefulWidget {
  const _StartingPositionStep({
    required this.programName,
    required this.curriculumId,
    required this.onComplete,
  });

  final String programName;
  final CurriculumId curriculumId;
  final ValueChanged<String?> onComplete;

  @override
  ConsumerState<_StartingPositionStep> createState() =>
      _StartingPositionStepState();
}

class _StartingPositionStepState extends ConsumerState<_StartingPositionStep> {
  List<ContentItem>? _allItems;
  bool _loading = true;

  // Drill-down state: level2 containers → leaf items within selected container.
  List<ContentItem> _containers = []; // e.g. list of Masechtos
  ContentItem? _selectedContainer; // e.g. selected Masechta
  List<ContentItem> _leaves = []; // e.g. Dapim within selected Masechta
  ContentItem? _selectedLeaf; // e.g. selected Daf

  String _containerLabel = 'Section'; // e.g. "Masechta"
  String _leafLabel = 'Item'; // e.g. "Daf"

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final repo = ref.read(contentRepositoryProvider);
      final config = await repo.getHierarchyConfig(widget.curriculumId);
      final items = await repo.getContentForCurriculum(widget.curriculumId);

      // Use hierarchy labels (e.g. ["Seder","Masechta","Daf","Amud"])
      final labels = config.levelLabels;
      // Pick the two most useful levels for drill-down.
      // Typically level2 (Masechta) → level3+level4 leaf (Daf).
      // For 2-level curricula, use level1 → leaves.
      final containerLvl = labels.length >= 3 ? 1 : 0; // 0-indexed
      final containerLevelLabel = containerLvl < labels.length
          ? labels[containerLvl]
          : 'Section';
      final leafLevelLabel = containerLvl + 1 < labels.length
          ? labels[containerLvl + 1]
          : 'Item';

      // Get distinct containers (non-leaf items at the container level).
      final containers = <String, ContentItem>{};
      for (final item in items) {
        if (item.isLeaf) continue;
        final key = containerLvl == 0 ? item.level1 : item.level2;
        if (key != null && !containers.containsKey(key)) {
          containers[key] = item;
        }
      }

      if (!mounted) return;
      setState(() {
        _allItems = items;
        _containers = containers.values.toList();
        _containerLabel = containerLevelLabel;
        _leafLabel = leafLevelLabel;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onContainerSelected(ContentItem container) {
    if (_allItems == null) return;

    // Find leaf items within this container.
    final leaves = _allItems!.where((item) {
      if (!item.isLeaf) return false;
      // Match by the container's level
      if (container.level2 != null) {
        return item.level2 == container.level2;
      }
      return item.level1 == container.level1;
    }).toList();

    setState(() {
      _selectedContainer = container;
      _leaves = leaves;
      _selectedLeaf = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedContainer = null;
      _leaves = [];
      _selectedLeaf = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
          const SizedBox(height: 4),
          Text(
            'Select the $_leafLabel you are currently up to.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Show selected item chip
          if (_selectedLeaf != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLeaf!.displayNameEn,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            _selectedLeaf!.displayNameHe,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelection,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Breadcrumb / back button when drilled into a container
          if (_selectedContainer != null && _selectedLeaf == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _clearSelection,
                    tooltip: 'Back to $_containerLabel list',
                  ),
                  Text(
                    _selectedContainer!.displayNameEn,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),

          // Content list
          if (_selectedLeaf == null)
            Expanded(
              child: _selectedContainer == null
                  ? _buildContainerList(theme)
                  : _buildLeafList(theme),
            )
          else
            const Spacer(),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onComplete(null),
                  child: const Text('Start from beginning'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedLeaf != null
                      ? () => widget.onComplete(_selectedLeaf!.sefariaRef)
                      : null,
                  child: const Text('Start here'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContainerList(ThemeData theme) {
    return ListView.builder(
      itemCount: _containers.length,
      itemBuilder: (context, index) {
        final container = _containers[index];
        return ListTile(
          title: Text(container.displayNameEn),
          subtitle: Text(container.displayNameHe),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _onContainerSelected(container),
        );
      },
    );
  }

  Widget _buildLeafList(ThemeData theme) {
    return ListView.builder(
      itemCount: _leaves.length,
      itemBuilder: (context, index) {
        final leaf = _leaves[index];
        final isSelected = _selectedLeaf?.sefariaRef == leaf.sefariaRef;
        return ListTile(
          title: Text(leaf.displayNameEn),
          subtitle: Text(leaf.displayNameHe),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          leading: isSelected
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : const Icon(Icons.circle_outlined),
          onTap: () => setState(() => _selectedLeaf = leaf),
        );
      },
    );
  }
}

// ── Chazara Inline Setup ───────────────────────────────────────────────────
//
// Single-screen חזרה configuration. Per DNI-180:
//   "Choose a preset, customize stages, or 'no חזרה'"
//   "All חזרה config on ONE screen"
// Replaces a Navigator.push to LearningProcessWizardScreen.

class _ChazaraInlineSetup extends StatefulWidget {
  const _ChazaraInlineSetup({
    required this.curriculumId,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final String headerTitle;
  final String headerSubtitle;
  final ValueChanged<LearningProcessWizardResult?> onComplete;

  @override
  State<_ChazaraInlineSetup> createState() => _ChazaraInlineSetupState();
}

/// Built-in preset templates expressed as round delays in days.
class _ChazaraPreset {
  const _ChazaraPreset({required this.label, required this.delays});
  final String label;
  final List<int> delays;
}

class _ChazaraInlineSetupState extends State<_ChazaraInlineSetup> {
  static const List<_ChazaraPreset> _presets = [
    _ChazaraPreset(label: 'לימוד only', delays: []),
    _ChazaraPreset(label: '1 day', delays: [1]),
    _ChazaraPreset(label: '1 + 7 days', delays: [1, 7]),
    _ChazaraPreset(label: '1 + 7 + 30 days', delays: [1, 7, 30]),
  ];

  /// Index of selected preset, or -1 for "Custom".
  int _selectedPresetIndex = 2; // default: 1 + 7 days
  late List<int> _customDelays;

  @override
  void initState() {
    super.initState();
    _customDelays = List.of(_presets[_selectedPresetIndex].delays);
  }

  List<int> get _activeDelays => _selectedPresetIndex >= 0
      ? _presets[_selectedPresetIndex].delays
      : _customDelays;

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _customDelays = List.of(_presets[index].delays);
    });
  }

  void _selectCustom() {
    setState(() {
      _selectedPresetIndex = -1;
      if (_customDelays.isEmpty) _customDelays = [1];
    });
  }

  void _addCustomRound() {
    setState(() {
      final next = _customDelays.isEmpty ? 1 : _customDelays.last * 2;
      _customDelays.add(next);
    });
  }

  void _removeCustomRound(int index) {
    setState(() => _customDelays.removeAt(index));
  }

  void _updateCustomRound(int index, int value) {
    setState(() => _customDelays[index] = value);
  }

  void _confirm() {
    final delays = _activeDelays;
    if (delays.isEmpty) {
      // לימוד only — equivalent to "no review".
      widget.onComplete(
        LearningProcessWizardResult(
          wizardResult: WizardResult(
            curriculumId: widget.curriculumId,
            choice: WizardChoice.noReview,
          ),
        ),
      );
      return;
    }

    final rounds = <CustomRound>[];
    for (var i = 0; i < delays.length; i++) {
      rounds.add(
        CustomRound(
          label: HebrewTerms.getChazaraStageName(i + 1),
          scheduleType: ScheduleType.delay,
          delayDays: delays[i],
        ),
      );
    }
    widget.onComplete(
      LearningProcessWizardResult(
        wizardResult: WizardResult(
          curriculumId: widget.curriculumId,
          choice: WizardChoice.custom,
          customRounds: rounds,
        ),
      ),
    );
  }

  void _skip() => widget.onComplete(null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.headerTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            widget.headerSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Presets
                  for (var i = 0; i < _presets.length; i++)
                    _PresetTile(
                      label: _presets[i].label,
                      stagesPreview: _stagesPreview(_presets[i].delays),
                      isSelected: _selectedPresetIndex == i,
                      onTap: () => _selectPreset(i),
                    ),
                  // Custom
                  _PresetTile(
                    label: 'Custom',
                    stagesPreview: _selectedPresetIndex == -1
                        ? _stagesPreview(_customDelays)
                        : 'Build your own',
                    isSelected: _selectedPresetIndex == -1,
                    onTap: _selectCustom,
                  ),
                  if (_selectedPresetIndex == -1) ...[
                    const SizedBox(height: 12),
                    for (var i = 0; i < _customDelays.length; i++)
                      _CustomRoundEditor(
                        label: HebrewTerms.getChazaraStageName(i + 1),
                        delayDays: _customDelays[i],
                        onChanged: (v) => _updateCustomRound(i, v),
                        onRemove: () => _removeCustomRound(i),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _customDelays.length >= 5
                            ? null
                            : _addCustomRound,
                        icon: const Icon(Icons.add),
                        label: const Text('Add a round'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _confirm, child: const Text('Continue')),
          TextButton(onPressed: _skip, child: const Text('Skip (no review)')),
        ],
      ),
    );
  }

  String _stagesPreview(List<int> delays) {
    if (delays.isEmpty) return HebrewTerms.stageLearn;
    final parts = <String>[HebrewTerms.stageLearn];
    for (var i = 0; i < delays.length; i++) {
      parts.add('${HebrewTerms.getChazaraStageName(i + 1)} (+${delays[i]}d)');
    }
    return parts.join(' → ');
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.label,
    required this.stagesPreview,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String stagesPreview;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      stagesPreview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomRoundEditor extends StatelessWidget {
  const _CustomRoundEditor({
    required this.label,
    required this.delayDays,
    required this.onChanged,
    required this.onRemove,
  });

  final String label;
  final int delayDays;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(label, style: theme.textTheme.titleSmall),
            ),
            Expanded(
              child: Slider(
                value: delayDays.toDouble().clamp(1, 60),
                min: 1,
                max: 60,
                divisions: 59,
                label: '${delayDays}d',
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${delayDays}d',
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}
