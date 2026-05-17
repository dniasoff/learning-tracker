import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_bulk_mark.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_chazara_readonly.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_goal.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_scope.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_starting_position.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/curriculum_picker_step.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/program_selection_step.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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
/// Program-aware: auto-fills/skips steps based on selected program.
class AddTrackFlow extends ConsumerStatefulWidget {
  const AddTrackFlow({
    required this.profileId,
    required this.isOnboarding,
    this.onComplete,
    this.onCancel,
    super.key,
  });

  final int profileId;
  final bool isOnboarding;
  final ValueChanged<AddTrackResult>? onComplete;
  final VoidCallback? onCancel;

  @override
  ConsumerState<AddTrackFlow> createState() => _AddTrackFlowState();
}

class _AddTrackFlowState extends ConsumerState<AddTrackFlow> {
  AddTrackState _state = const AddTrackState();
  late final PageController _pageController;
  bool _isAnimating = false;
  bool _pendingAdvance = false;
  bool _isFinishing = false;

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

  /// Whether the selected curriculum has any active programs (shows program step).
  bool get _hasProgramStepForCurriculum {
    final id = _state.curriculumId;
    if (id == null) return false;
    return LearningProgramRepository.instance
        .getActiveProgramsByCurriculumType(id.storageKey)
        .isNotEmpty;
  }

  /// Active steps — program-aware skipping.
  List<AddTrackStep> get _activeSteps {
    final steps = <AddTrackStep>[AddTrackStep.curriculum];

    if (_hasProgramStepForCurriculum) {
      steps.add(AddTrackStep.program);
    }

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

    // Final step:
    // - Program tracks: starting position only
    // - Self-paced tracks: optional prior completion marking
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
      selectedProgram = LearningProgramRepository.instance.getProgramById(
        programId,
      );
    }

    final programsExistForResume =
        curriculum != null &&
        LearningProgramRepository.instance
            .getActiveProgramsByCurriculumType(curriculum.storageKey)
            .isNotEmpty;

    var resolvedStep =
        AddTrackStep.values[stepIndex.clamp(0, AddTrackStep.values.length - 1)];

    // Saved "program" step is invalid if this curriculum has no program picker.
    if (resolvedStep == AddTrackStep.program && !programsExistForResume) {
      resolvedStep = AddTrackStep.scope;
    }

    setState(() {
      _state = _state.copyWith(
        currentStep: resolvedStep,
        curriculumId: curriculum,
        scopeSelections: scopes,
        // Only restore program state when the saved curriculum actually has
        // programs — otherwise a stale program from a prior run bleeds into
        // a curriculum that shouldn't have one (e.g. Chumash showing Mishna Yomit).
        programId: programsExistForResume ? programId : null,
        programName: programsExistForResume ? programName : null,
        selectedProgram: programsExistForResume ? selectedProgram : null,
        studyDays: studyDays,
        trackLabel: label,
      );
    });

    final targetIndex = _activeSteps.indexOf(resolvedStep);
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
        barrierColor: Colors.black.withValues(alpha: 0.46),
        builder: (context) {
          final theme = Theme.of(context);
          return Dialog(
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              decoration: BoxDecoration(
                color: AppTheme.brandCreamCard,
                borderRadius: BorderRadius.circular(34),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE7EA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.exit_to_app_rounded,
                          color: Color(0xFFB43A4A),
                          size: 40,
                        ),
                      ),
                      Positioned(
                        top: -1,
                        right: -2,
                        child: Container(
                          width: 23,
                          height: 23,
                          decoration: BoxDecoration(
                            color: AppTheme.brandBlue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.brandCreamCard,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.question_mark_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Exit Track Setup?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.brandBlueDeep,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Are you sure you want to exit?\n'
                    'Your setup progress will be lost.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.brandInkMuted,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 2,
                      ),
                      child: Text(AppLocalizations.of(context)!.actionExit),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandInkMuted,
                        backgroundColor: const Color(0xFFF0F1F5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)!.actionCancel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (shouldExit != true) return;
    }
    await _clearSavedState();
    widget.onCancel?.call();
  }

  // ── Callbacks ──────────────────────────────────────────────────────────────

  void _onCurriculumSelected(CurriculumId curriculum) {
    // Curriculum activation (and track creation) is deferred to
    // TrackCreationService.createTrack() so that exiting mid-flow does not
    // leave a phantom track behind. Scope content loads from bundled assets.
    //
    // Always clear any stale program state from a previously resumed flow so
    // that selecting a curriculum with no programs (e.g. Chumash) doesn't
    // inherit a calendar program (e.g. Mishna Yomit) from last time.
    setState(
      () => _state = _state.copyWith(
        curriculumId: curriculum,
        contentActivated: true,
        programId: null,
        programName: null,
        selectedProgram: null,
      ),
    );
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

  void _onGoalComplete(GoalEntity? result) {
    setState(() => _state = _state.copyWith(goalResult: result));
    _goToNextStep();
  }

  Future<void> _onStartingPositionComplete(String? startingRef) async {
    setState(() => _state = _state.copyWith(startingRef: startingRef));
    // Program tracks end on the starting-position step.
    // After selecting "Start here", finish immediately.
    if (_isProgramTrack) {
      await _finishFlow();
      return;
    }
    _goToNextStep();
  }

  /// Shows a confirmation dialog before [_finishFlow] silently replaces an
  /// existing track. Returns true if the user pressed "Replace".
  Future<bool?> _confirmReplaceExistingTrack(CurriculumId curriculum) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final name = curriculumLabelText(ref, curriculum: curriculum);
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 32,
          ),
          title: Text(AppLocalizations.of(ctx)!.trackReplaceTitle(name)),
          content: Text(
            'You already have a $name track. Continuing will replace its '
            'study days, scope, review schedule, and goals with the new '
            'configuration. Completed sections stay with your account.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppLocalizations.of(ctx)!.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: Text(AppLocalizations.of(ctx)!.actionReplace),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishFlow({Set<HierarchySelection>? priorSelections}) async {
    if (_isFinishing) return;
    _isFinishing = true;

    // If a track already exists for this curriculum, createTrack will
    // silently replace its stages, study days, scope, and goals. Confirm
    // with the user before that lands — the warning icon on the curriculum
    // tile is informational; this is the destructive moment.
    final curriculum = _state.curriculumId!;
    final activeCurricula =
        ref.read(dashboardActiveCurriculaProvider).asData?.value ??
        const <CurriculumId>[];
    if (activeCurricula.contains(curriculum)) {
      final confirmed = await _confirmReplaceExistingTrack(curriculum);
      if (confirmed != true) {
        _isFinishing = false;
        return;
      }
    }

    final result = AddTrackResult(
      curriculumId: curriculum,
      label: _getSmartDefault(),
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

      await invalidateAfterTrackDataChange(ref, widget.profileId);

      if (!_isProgramTrack && priorSelections != null) {
        unawaited(
          _applySelfPacedPriorCompletions(priorSelections).then(
            (_) {
              // Bulk marking completed in background.
            },
            onError: (_) {
              // Do not block navigation if bulk marking fails.
              // The track is already created successfully.
            },
          ),
        );
      }

      await _clearSavedState();
      widget.onComplete?.call(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSaveTrackFailed),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.actionRetry,
            onPressed: _finishFlow,
          ),
        ),
      );
    } finally {
      _isFinishing = false;
    }
  }

  Future<({int itemCount, int completionCount})>
  _applySelfPacedPriorCompletions(Set<HierarchySelection> selections) async {
    if (selections.isEmpty) return (itemCount: 0, completionCount: 0);

    final service = ref.read(bulkPriorCompletionServiceProvider);
    final curriculum = _state.curriculumId!;

    final resolved = await service.resolveSelections(
      curriculumId: curriculum,
      selections: selections.toList(),
    );
    if (resolved.isEmpty) {
      return (itemCount: 0, completionCount: 0);
    }

    final completion = await service.execute(
      curriculumId: curriculum,
      resolvedItems: resolved,
      stageIds: const [1],
      profileId: widget.profileId,
    );

    // Refresh dashboard/progress/task views immediately.
    await onTrackChanged(ref, widget.profileId);

    return (
      itemCount: completion.itemCount,
      completionCount: completion.completionCount,
    );
  }

  String _getSmartDefault() {
    if (_state.programName != null) return _state.programName!;
    if (_state.scopeSelections != null && _state.scopeSelections!.isNotEmpty) {
      return _state.scopeSelections!.last.value;
    }
    final c = _state.curriculumId;
    if (c == null) return '';
    return curriculumLabelText(ref, curriculum: c);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;
    final progress = _currentIndex / steps.length;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToPreviousStep();
      },
      child: ColoredBox(
        color: const Color(0xFFF4F5F7),
        child: SafeArea(
          child: Column(
            children: [
              if (steps.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'STEP ${_currentIndex + 1} OF ${steps.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppTheme.brandInkMuted,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).round()}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppTheme.brandBlueDeep,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE1E4EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.brandBlueBright,
                          ),
                        ),
                      ),
                    ],
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
      ),
    );
  }

  Widget _buildStep(AddTrackStep step) {
    if (step != AddTrackStep.curriculum && _state.curriculumId == null) {
      return const SizedBox.shrink();
    }

    return switch (step) {
      AddTrackStep.curriculum => _buildCurriculumStep(),
      AddTrackStep.program => ProgramSelectionStep(
        curriculumId: _state.curriculumId!,
        onSelected: _onProgramSelected,
      ),
      AddTrackStep.scope => _buildScopeStep(),
      AddTrackStep.studyDays => _buildStudyDaysStep(),
      AddTrackStep.chazaraSetup => _buildChazaraStep(),
      AddTrackStep.goal => _buildGoalStep(),
      AddTrackStep.trackName => const SizedBox.shrink(),
      AddTrackStep.bulkMark => _buildScreen8(),
    };
  }

  Widget _buildCurriculumStep() {
    final activeAsync = ref.watch(dashboardActiveCurriculaProvider);
    return activeAsync.when(
      data: (list) => CurriculumPickerStep(
        onSelected: _onCurriculumSelected,
        isOnboarding: widget.isOnboarding,
        existingTrackCurricula: list.toSet(),
      ),
      loading: () => CurriculumPickerStep(
        onSelected: _onCurriculumSelected,
        isOnboarding: widget.isOnboarding,
      ),
      error: (_, __) => CurriculumPickerStep(
        onSelected: _onCurriculumSelected,
        isOnboarding: widget.isOnboarding,
      ),
    );
  }

  // ── Step Builders ──────────────────────────────────────────────────────────

  Widget _buildScopeStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    return ScopeStepContent(
      curriculumId: _state.curriculumId!,
      onComplete: _onScopeComplete,
    );
  }

  Widget _buildStudyDaysStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

    // Program mode: auto-fill read-only
    if (_isProgramTrack) {
      return StudyDaysReadOnly(
        programName: _state.programName ?? '',
        onContinue: () =>
            _onStudyDaysComplete(Map<int, String>.from(kDefaultStudyDays)),
      );
    }

    // Self-paced: editable vertical list
    return StudyDaysEditable(onComplete: _onStudyDaysComplete);
  }

  Widget _buildChazaraStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

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

      return ChazaraReadOnlyStep(
        programName: _state.programName ?? '',
        stages: chazaraStages,
        onContinue: () => _onChazaraComplete(null),
      );
    }

    // Program with OPEN chazara → offer optional inline setup
    // Self-paced → inline setup
    // Both paths use ChazaraInlineSetup; differ only in header copy.
    final headerTitle = _isProgramTrack
        ? 'Add Review?'
        : 'How do you want to review?';
    final headerSubtitle = _isProgramTrack
        ? '${_state.programName} doesn\'t include a review schedule. '
              'Set one up now or skip.'
        : 'Pick a preset or build your own חזרה schedule.';

    return ChazaraInlineSetup(
      curriculumId: _state.curriculumId!,
      headerTitle: headerTitle,
      headerSubtitle: headerSubtitle,
      onComplete: _onChazaraComplete,
    );
  }

  Widget _buildGoalStep() {
    if (_state.curriculumId == null) return const SizedBox.shrink();
    return SelfPacedGoalStep(
      curriculumId: _state.curriculumId!,
      studyDays: _state.studyDays ?? kDefaultStudyDays,
      onComplete: _onGoalComplete,
    );
  }

  /// Screen 8: Program start position OR self-paced prior progress.
  Widget _buildScreen8() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

    if (!_isProgramTrack) {
      return SelfPacedPriorProgressStep(
        curriculumId: _state.curriculumId!,
        scopeSelections: _state.scopeSelections,
        onSkip: () => unawaited(_finishFlow()),
        onMarkCompleted: (selections) =>
            unawaited(_finishFlow(priorSelections: selections)),
      );
    }

    return StartingPositionStep(
      programName: _state.programName ?? '',
      curriculumId: _state.curriculumId!,
      selectedProgram: _state.selectedProgram as LearningProgramData?,
      onComplete: _onStartingPositionComplete,
    );
  }
}
