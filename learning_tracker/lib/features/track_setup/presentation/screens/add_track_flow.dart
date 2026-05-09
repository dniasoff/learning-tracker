import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
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

/// Day labels in Jewish week order (Sunday first, Shabbos last).
const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Shabbos'];

/// ISO day numbers in Jewish week order.
const _dayNumbers = [7, 1, 2, 3, 4, 5, 6];

/// Inclusive count of dates in [startInclusive, endInclusive] whose weekday
/// is a study day per [studyDays] map (same keys as kDefaultStudyDays).
int _countStudyDaysInInclusiveMapRange(
  Map<int, String> studyDays,
  DateTime startInclusive,
  DateTime endInclusive,
) {
  final studyWeekdays = <int>{
    for (final e in studyDays.entries)
      if (e.value == 'study') e.key,
  };
  if (studyWeekdays.isEmpty) {
    for (var i = 1; i <= 7; i++) {
      studyWeekdays.add(i);
    }
  }
  var d = DateTime(
    startInclusive.year,
    startInclusive.month,
    startInclusive.day,
  );
  final end = DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
  if (d.isAfter(end)) return 0;
  var n = 0;
  while (!d.isAfter(end)) {
    if (studyWeekdays.contains(d.weekday)) n++;
    d = d.add(const Duration(days: 1));
  }
  return n;
}

DateTime _localDateOnlyFromDt(DateTime utc) {
  final l = utc.toLocal();
  return DateTime(l.year, l.month, l.day);
}

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
        programId: programId,
        programName: programName,
        selectedProgram: selectedProgram,
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
                      child: const Text('Exit'),
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
                      child: const Text('Cancel'),
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
    setState(
      () => _state = _state.copyWith(
        curriculumId: curriculum,
        contentActivated: true,
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

  void _onGoalComplete(GoalFormResult? result) {
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
        final hebrewOnly = ref.read(hebrewTermsScriptProvider);
        final name = hebrewOnly
            ? curriculum.displayNameHe
            : curriculum.displayNameEn;
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 32,
          ),
          title: Text('Replace your $name track?'),
          content: Text(
            'You already have a $name track. Continuing will replace its '
            'study days, scope, review schedule, and goals with the new '
            'configuration. Completed sections stay with your account.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishFlow({
    _SelfPacedPriorCompletionSelection? priorCompletionSelection,
  }) async {
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

      if (!_isProgramTrack && priorCompletionSelection != null) {
        unawaited(
          _applySelfPacedPriorCompletions(priorCompletionSelection).then(
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
          content: const Text('Failed to save track. Please try again.'),
          action: SnackBarAction(label: 'Retry', onPressed: _finishFlow),
        ),
      );
    } finally {
      _isFinishing = false;
    }
  }

  Future<({int itemCount, int completionCount})>
  _applySelfPacedPriorCompletions(
    _SelfPacedPriorCompletionSelection selection,
  ) async {
    final service = ref.read(bulkPriorCompletionServiceProvider);
    final curriculum = _state.curriculumId!;

    final hierarchySelections = selection.markAll
        ? const [HierarchySelection()]
        : selection.selectedScopes.map((s) {
            return switch (s.level) {
              1 => HierarchySelection(level1: s.value),
              2 => HierarchySelection(level2: s.value),
              3 => HierarchySelection(level3: s.value),
              4 => HierarchySelection(level4: s.value),
              _ => const HierarchySelection(),
            };
          }).toList();

    if (hierarchySelections.isEmpty) {
      return (itemCount: 0, completionCount: 0);
    }

    final resolved = await service.resolveSelections(
      curriculumId: curriculum,
      selections: hierarchySelections,
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
    ref.invalidate(dashboardCompletionPercentageProvider(curriculum));
    ref.invalidate(dashboardLastCompletionProvider(curriculum));
    ref.invalidate(progressOverviewStatsProvider);
    ref.invalidate(allDailyTasksProvider);

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
    return _state.curriculumId?.displayNameHe ?? '';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;
    final progress = (_currentIndex + 1) / steps.length;
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
    return _StudyDaysEditable(onComplete: _onStudyDaysComplete);
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

      String normalizeStageName(String raw) {
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
              'Review stages set by ${_state.programName}',
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
              child: chazaraStages.isEmpty
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
                      itemCount: chazaraStages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final stage =
                            chazaraStages[index] as Map<String, dynamic>;
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
                            border: Border.all(color: const Color(0xFFE7EAF1)),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
              onPressed: () => _onChazaraComplete(null),
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
    return _SelfPacedGoalStep(
      curriculumId: _state.curriculumId!,
      studyDays: _state.studyDays ?? kDefaultStudyDays,
      onComplete: _onGoalComplete,
    );
  }

  /// Screen 8: Program start position OR self-paced prior progress.
  Widget _buildScreen8() {
    if (_state.curriculumId == null) return const SizedBox.shrink();

    if (!_isProgramTrack) {
      return _SelfPacedPriorProgressStep(
        curriculumId: _state.curriculumId!,
        scopeSelections: _state.scopeSelections,
        onSkip: () => unawaited(_finishFlow()),
        onMarkCompleted: (selection) =>
            unawaited(_finishFlow(priorCompletionSelection: selection)),
      );
    }

    return _StartingPositionStep(
      programName: _state.programName ?? '',
      curriculumId: _state.curriculumId!,
      selectedProgram: _state.selectedProgram as LearningProgramData?,
      onComplete: _onStartingPositionComplete,
    );
  }
}

class _SelfPacedPriorProgressStep extends ConsumerWidget {
  const _SelfPacedPriorProgressStep({
    required this.curriculumId,
    required this.scopeSelections,
    required this.onSkip,
    required this.onMarkCompleted,
  });

  final CurriculumId curriculumId;
  final List<ScopeEntry>? scopeSelections;
  final VoidCallback onSkip;
  final ValueChanged<_SelfPacedPriorCompletionSelection> onMarkCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasExplicitScopes =
        scopeSelections != null && scopeSelections!.isNotEmpty;
    final generatedScopesAsync = hasExplicitScopes
        ? null
        : ref.watch(curriculumContentProvider(curriculumId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mark Prior Learning', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Do you want to mark parts you already learned as completed?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose which sections to mark in ${curriculumId.displayNameHe}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: hasExplicitScopes
                ? _SelfPacedSelectionList(
                    scopeSelections: scopeSelections,
                    selectAllByDefault: false,
                    onSkip: onSkip,
                    onMarkCompleted: onMarkCompleted,
                  )
                : generatedScopesAsync!.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _SelfPacedSelectionList(
                      scopeSelections: const [],
                      selectAllByDefault: false,
                      onSkip: onSkip,
                      onMarkCompleted: onMarkCompleted,
                    ),
                    data: (items) {
                      final seen = <String>{};
                      final topLevelSelections = <ScopeEntry>[];
                      for (final item in items) {
                        final level1 = item.level1;
                        if (level1.isEmpty) continue;
                        if (!seen.add(level1)) continue;
                        topLevelSelections.add(
                          ScopeEntry(level: 1, value: level1),
                        );
                      }
                      return _SelfPacedSelectionList(
                        scopeSelections: topLevelSelections,
                        selectAllByDefault: false,
                        onSkip: onSkip,
                        onMarkCompleted: onMarkCompleted,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SelfPacedSelectionList extends StatefulWidget {
  const _SelfPacedSelectionList({
    required this.scopeSelections,
    required this.selectAllByDefault,
    required this.onSkip,
    required this.onMarkCompleted,
  });

  final List<ScopeEntry>? scopeSelections;
  final bool selectAllByDefault;
  final VoidCallback onSkip;
  final ValueChanged<_SelfPacedPriorCompletionSelection> onMarkCompleted;

  @override
  State<_SelfPacedSelectionList> createState() =>
      _SelfPacedSelectionListState();
}

class _SelfPacedSelectionListState extends State<_SelfPacedSelectionList> {
  late final List<ScopeEntry> _entries;
  final _selectedIndexes = <int>{};
  bool _markAll = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.scopeSelections ?? const <ScopeEntry>[];
    if (_entries.isNotEmpty && widget.selectAllByDefault) {
      _selectedIndexes.addAll(List<int>.generate(_entries.length, (i) => i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canMark = _markAll || _selectedIndexes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Have you already completed some of these sections?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        _SelectionCard(
          title: 'Mark everything as finished',
          subtitle: 'Best if you are starting a new review cycle',
          selected: _markAll,
          onChanged: (checked) {
            setState(() {
              _markAll = checked;
              _selectedIndexes
                ..clear()
                ..addAll(
                  checked
                      ? List<int>.generate(_entries.length, (index) => index)
                      : const <int>[],
                );
            });
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Text(
                    'No specific folders were selected, but you can still mark all as completed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final selected = _selectedIndexes.contains(index);
                    return _SelectionCard(
                      title: entry.value,
                      subtitle: 'Selected folder',
                      selected: selected,
                      onChanged: (checked) {
                        setState(() {
                          _markAll = false;
                          if (checked) {
                            _selectedIndexes.add(index);
                          } else {
                            _selectedIndexes.remove(index);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onSkip,
                child: const Text('Skip for now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: canMark
                    ? () {
                        final selectedScopes = (_markAll && _entries.isNotEmpty)
                            ? _entries
                            : _selectedIndexes.map((i) => _entries[i]).toList();
                        widget.onMarkCompleted(
                          _SelfPacedPriorCompletionSelection(
                            markAll: _markAll && _entries.isEmpty,
                            selectedScopes: selectedScopes,
                          ),
                        );
                      }
                    : null,
                child: const Text('Mark Completed'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfPacedPriorCompletionSelection {
  const _SelfPacedPriorCompletionSelection({
    required this.markAll,
    required this.selectedScopes,
  });

  final bool markAll;
  final List<ScopeEntry> selectedScopes;
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

  /// Whether every value in [values] is directly selected at the current level.
  bool _allValuesDirectlySelected(List<String> values) {
    if (values.isEmpty) return false;
    return values.every(_isDirectlySelected);
  }

  /// Select every section at the current list, or deselect if already all direct.
  void _toggleSelectAllCurrentLevel(List<ContentItem> items) {
    final values = _valuesAtCurrentLevel(items);
    if (values.isEmpty) return;
    setState(() {
      if (_allValuesDirectlySelected(values)) {
        for (final v in values) {
          _selections.removeWhere(
            (s) => s.level == _currentLevel && s.value == v,
          );
        }
      } else {
        _selections.removeWhere((s) => s.level > _currentLevel);
        for (final v in values) {
          if (!_selections.any(
            (s) => s.level == _currentLevel && s.value == v,
          )) {
            _selections.add(ScopeEntry(level: _currentLevel, value: v));
          }
        }
      }
    });
  }

  int _childCountForValue(List<ContentItem> items, String value) {
    final nextLevel = _currentLevel + 1;
    if (nextLevel > _hierarchy.maxLevels) return 0;
    final seen = <String>{};
    for (final item in items) {
      var matches = true;
      for (final crumb in _breadcrumbs) {
        if (_getItemLevel(item, crumb.level) != crumb.value) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      if (_getItemLevel(item, _currentLevel) != value) continue;
      final child = _getItemLevel(item, nextLevel);
      if (child != null) seen.add(child);
    }
    return seen.length;
  }

  String _scopeDescription(String value) {
    if (widget.curriculumId == CurriculumId.mishnayos) {
      return switch (value.toLowerCase()) {
        'seder zeraim' => 'Seeds & Agriculture',
        'seder moed' => 'Festivals & Sabbaths',
        'seder nashim' => 'Women & Marriage',
        'seder nezikin' => 'Damages & Civil Law',
        'seder kodashim' => 'Temple Service & Sacrifices',
        'seder taharos' => 'Purity & Ritual Law',
        _ => 'Core section focus',
      };
    }
    return 'Core section focus';
  }

  IconData _scopeIcon(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('zeraim')) return Icons.eco_rounded;
    if (normalized.contains('moed')) return Icons.calendar_month_rounded;
    if (normalized.contains('nashim')) return Icons.family_restroom_rounded;
    if (normalized.contains('nezikin')) return Icons.balance_rounded;
    if (normalized.contains('kodashim')) return Icons.temple_buddhist_rounded;
    if (normalized.contains('taharos')) return Icons.water_drop_rounded;
    return Icons.book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.selfPacedScopeTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE5E9FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 15,
                      color: AppTheme.brandBlueDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.curriculumId.displayNameEn,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.brandBlueDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                return _breadcrumbs.isEmpty
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final values = _valuesAtCurrentLevel(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.brandBlueDeep, AppTheme.brandBlueBright],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26084BB8),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onComplete(null),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.learnEntireCurriculumCta,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.learnEntireCurriculumSubtitle(
                              widget.curriculumId.displayNameHe,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const CircleAvatar(
                      radius: 21,
                      backgroundColor: Color(0x40FFFFFF),
                      child: Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9ECF2)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Text(
                  widget.curriculumId.displayNameEn,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.brandBlueDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.brandInkMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.level1Selection(
                    widget.curriculumId.displayNameEn,
                    _labelForLevel(1),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.brandInk,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _toggleSelectAllCurrentLevel(items),
              icon: Icon(
                _allValuesDirectlySelected(values)
                    ? Icons.remove_done
                    : Icons.select_all,
                size: 20,
              ),
              label: Text(
                _allValuesDirectlySelected(values)
                    ? l10n.deselectAllInThisList
                    : l10n.selectAllInThisList,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: values.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final value = values[index];
              final selected = _isDirectlySelected(value);
              final count = _childCountForValue(items, value);
              final canDrillDeeper = _currentLevel < _maxSelectableLevel;
              return _ScopeLevelTile(
                title: value,
                subtitle:
                    '$count ${_labelForLevel(2)} • ${_scopeDescription(value)}',
                icon: _scopeIcon(value),
                selected: selected,
                badgeText: selected ? l10n.scopeSelectedBadge : null,
                onCheck: () => _toggleSelection(value),
                canDrill: canDrillDeeper,
                onDrill: canDrillDeeper ? () => _drillInto(value, items) : null,
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _selections.isNotEmpty ? _done : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            _selections.isEmpty
                ? l10n.selectAtLeastOne
                : l10n.continueWithSelectionCount(_totalSelectionCount),
          ),
        ),
      ],
    );
  }

  /// Drill-down view with breadcrumbs and item list.
  Widget _buildHierarchyView(List<ContentItem> items) {
    final l10n = AppLocalizations.of(context)!;
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
        if (values.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _toggleSelectAllCurrentLevel(items),
              icon: Icon(
                _allValuesDirectlySelected(values)
                    ? Icons.remove_done
                    : Icons.select_all,
                size: 20,
              ),
              label: Text(
                _allValuesDirectlySelected(values)
                    ? l10n.deselectAllInThisList
                    : l10n.selectAllInThisList,
              ),
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
                ? l10n.selectAtLeastOne
                : l10n.continueWithSelectionCount(_totalSelectionCount),
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

class _ScopeLevelTile extends StatelessWidget {
  const _ScopeLevelTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onCheck,
    required this.canDrill,
    this.onDrill,
    this.badgeText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final String? badgeText;
  final VoidCallback onCheck;
  final bool canDrill;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9ECF2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onCheck,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF3F4F8),
                  child: Icon(icon, size: 19, color: AppTheme.brandBlueDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3D4A5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                badgeText!,
                                style: const TextStyle(
                                  color: Color(0xFF594624),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.brandInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canDrill)
                      IconButton(
                        onPressed: onDrill,
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.brandInkMuted,
                        ),
                        tooltip: 'Show contents',
                      ),
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onCheck(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Study days — vertical layout, all 7 active by default, "Shabbos" label.
class _StudyDaysEditable extends StatefulWidget {
  const _StudyDaysEditable({required this.onComplete});

  final ValueChanged<Map<int, String>> onComplete;

  @override
  State<_StudyDaysEditable> createState() => _StudyDaysEditableState();
}

class _StudyDaysEditableState extends State<_StudyDaysEditable> {
  late final Map<int, String> _days;

  @override
  void initState() {
    super.initState();
    _days = Map<int, String>.from(kDefaultStudyDays);
    // All 7 days default to study. Per the platform-wide rule "all days
    // default to a learning day" — users in many communities consider
    // Shabbos a primary learning day, so opting them out by default was a
    // mismatch. Users can still toggle Shabbos off explicitly.
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
            'Study Days',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Which days do you learn?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (context, index) {
                final dayNum = _dayNumbers[index];
                final isActive = _days[dayNum] == 'study';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StudyDayCard(
                    initial: _dayLabels[index].substring(0, 1),
                    title: _dayName(dayNum),
                    subtitle: _daySubtitle(dayNum),
                    subtitleColor: dayNum == 5
                        ? const Color(0xFFAA2F39)
                        : AppTheme.brandInkMuted,
                    activeColor: dayNum == 5
                        ? const Color(0xFFFFE1E4)
                        : const Color(0xFFE9ECF2),
                    isShabbos: dayNum == 6,
                    isOn: isActive,
                    onChanged: (v) =>
                        setState(() => _days[dayNum] = v ? 'study' : 'review'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onComplete(Map.from(_days)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dayName(int dayNum) {
    return switch (dayNum) {
      7 => 'Sunday',
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Shabbos',
      _ => 'Day',
    };
  }

  String _daySubtitle(int dayNum) {
    return switch (dayNum) {
      7 => 'Yom Rishon',
      5 => 'EREV SHABBOS',
      6 => 'DAY OF REST',
      _ => '',
    };
  }
}

class _StudyDayCard extends StatelessWidget {
  const _StudyDayCard({
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.activeColor,
    required this.isShabbos,
    required this.isOn,
    required this.onChanged,
  });

  final String initial;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Color activeColor;
  final bool isShabbos;
  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isShabbos ? const Color(0xFFD8DCE5) : const Color(0xFFE8EBF2),
        ),
        boxShadow: isShabbos
            ? null
            : const [
                BoxShadow(
                  color: Color(0x121D2939),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: activeColor,
              child: Text(
                initial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.brandInkMuted,
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
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.brandBlueBright,
            ),
          ],
        ),
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

class _SelfPacedGoalStep extends ConsumerStatefulWidget {
  const _SelfPacedGoalStep({
    required this.curriculumId,
    required this.studyDays,
    required this.onComplete,
  });

  final CurriculumId curriculumId;
  final Map<int, String> studyDays;
  final ValueChanged<GoalFormResult?> onComplete;

  @override
  ConsumerState<_SelfPacedGoalStep> createState() => _SelfPacedGoalStepState();
}

class _SelfPacedGoalStepState extends ConsumerState<_SelfPacedGoalStep> {
  int _paceValue = 1;
  String _paceUnit = 'per_week';
  DateTime? _deadline;
  String _mode = 'pace';

  @override
  void initState() {
    super.initState();
    final daily =
        CurriculumDefaults.defaultDailyTargets[widget.curriculumId] ?? 1;
    _paceValue = (daily * 7).clamp(1, 99);
    final now = DateTime.now();
    _deadline = DateTime(now.year, now.month, now.day);
  }

  String get _unitSingular => switch (widget.curriculumId) {
    CurriculumId.bavli || CurriculumId.yerushalmi => 'daf',
    CurriculumId.mishnayos => 'mishnah',
    _ => 'unit',
  };

  String get _unitPlural => switch (_unitSingular) {
    'daf' => 'dafim',
    'mishnah' => 'mishnayos',
    _ => 'units',
  };

  String _formatDate(DateTime value, {required bool useHebrew}) {
    if (useHebrew) {
      return HebrewCalendarUtils.gregorianToHebrew(value.toLocal());
    }
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _projectedFinishLabel(bool useHebrew) {
    final weeklyPace = _paceUnit == 'per_day' ? _paceValue * 7 : _paceValue;
    final days = (weeklyPace <= 0 ? 14 : (120 / weeklyPace * 7)).ceil();
    final projected = DateTime.now().add(Duration(days: days));
    return _formatDate(projected, useHebrew: useHebrew);
  }

  Future<void> _pickDeadline() async {
    final useHebrew = ref.read(useHebrewDateProvider);
    if (useHebrew) {
      final picked = await HebrewDatePicker.show(
        context,
        initialDate: _deadline,
      );
      if (picked != null) {
        setState(() {
          _deadline = picked;
          _mode = 'deadline';
        });
      }
      return;
    }
    final now = DateTime.now();
    final picked = await showLearningAppDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
        _mode = 'deadline';
      });
    }
  }

  /// Switches to deadline mode and opens the date picker (from frozen card).
  Future<void> _activateDeadlineMode() async {
    setState(() => _mode = 'deadline');
    await _pickDeadline();
  }

  /// When the other goal mode is active, show a blurred, non-interactive card
  /// with a hint; tap activates that mode.
  Widget _blurInactiveGoalOption({
    required BuildContext context,
    required String hint,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: hint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: Opacity(
                    opacity: 0.4,
                    child: AbsorbPointer(child: child),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandBlueDeep,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaceCard(ThemeData theme, bool useHebrew) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _mode == 'pace'
              ? AppTheme.brandBlueBright
              : const Color(0xFFE9ECF2),
          width: _mode == 'pace' ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFE5E9FF),
                  child: Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: AppTheme.brandBlueDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Target Pace',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_unitSingular[0].toUpperCase()}${_unitSingular.substring(1)} $_unitPlural ${_paceUnit == 'per_day' ? 'per day' : 'per week'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'per_day', label: Text('Per day')),
                ButtonSegment(value: 'per_week', label: Text('Per week')),
              ],
              selected: {_paceUnit},
              onSelectionChanged: (value) {
                setState(() {
                  _mode = 'pace';
                  _paceUnit = value.first;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _mode = 'pace';
                      if (_paceValue > 1) _paceValue -= 1;
                    });
                  },
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_paceValue',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _mode = 'pace';
                      _paceValue += 1;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            Text(
              'Estimated finish: ${_projectedFinishLabel(useHebrew)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.brandInkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUnitForEstimate(int perStudyDay) {
    final s = perStudyDay == 1 ? _unitSingular : _unitPlural;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildDeadlineCard(
    ThemeData theme,
    bool useHebrew,
    AppLocalizations l10n, {
    required int studyDaysInWindow,
    required int itemsPerStudyDay,
    required int totalScopeItems,
    bool scopeIsLoading = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _mode == 'deadline'
              ? AppTheme.brandBlueBright
              : const Color(0xFFE9ECF2),
          width: _mode == 'deadline' ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFF9E4C8),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Color(0xFF7D5411),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Set Deadline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDate(
                        _deadline ?? DateTime.now(),
                        useHebrew: useHebrew,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _mode == 'deadline'
                            ? AppTheme.brandInk
                            : AppTheme.brandInkMuted,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 17,
                      color: AppTheme.brandInkMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_deadline != null) ...[
              const SizedBox(height: 8),
              if (scopeIsLoading)
                Text(
                  l10n.addTrackGoalDeadlinePaceLineLoading,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (studyDaysInWindow <= 0)
                Text(
                  l10n.addTrackGoalDeadlineNoStudyDaysInWindow,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  l10n.addTrackGoalDeadlinePaceLine(
                    itemsPerStudyDay,
                    _formatUnitForEstimate(itemsPerStudyDay),
                    studyDaysInWindow,
                    totalScopeItems,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _continue() {
    if (_mode == 'deadline') {
      if (_deadline == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pick a deadline first.')));
        return;
      }
      final useHebrew = ref.read(useHebrewDateProvider);
      widget.onComplete(
        GoalFormResult(
          targetPercent: 100,
          goalType: 'deadline',
          targetDate: _deadline!.toUtc(),
          dateType: useHebrew ? 'hebrew' : 'gregorian',
          learningUnit:
              widget.curriculumId == CurriculumId.bavli ||
                  widget.curriculumId == CurriculumId.yerushalmi
              ? 'daf'
              : null,
        ),
      );
      return;
    }

    widget.onComplete(
      GoalFormResult(
        targetPercent: 100,
        goalType: 'pace',
        paceValue: _paceValue,
        paceUnit: _paceUnit,
        learningUnit:
            widget.curriculumId == CurriculumId.bavli ||
                widget.curriculumId == CurriculumId.yerushalmi
            ? 'daf'
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final useHebrew = ref.watch(useHebrewDateProvider);
    final scopeCountAsync = ref.watch(
      scopedItemCountProvider(widget.curriculumId),
    );
    final start = _localDateOnlyFromDt(DateTime.now());
    final end = _deadline != null
        ? _localDateOnlyFromDt(_deadline!.toLocal())
        : null;
    final studyDaysInWindow = end != null
        ? _countStudyDaysInInclusiveMapRange(widget.studyDays, start, end)
        : 0;
    final scopeLoading = scopeCountAsync.isLoading;
    final totalScopeItems = scopeCountAsync.asData?.value ?? 120;
    final itemsPerStudyDay = studyDaysInWindow > 0
        ? (totalScopeItems / studyDaysInWindow).ceil().clamp(1, 999999)
        : 0;

    final paceCard = _buildPaceCard(theme, useHebrew);
    final deadlineCard = _buildDeadlineCard(
      theme,
      useHebrew,
      l10n,
      studyDaysInWindow: studyDaysInWindow,
      itemsPerStudyDay: itemsPerStudyDay,
      totalScopeItems: totalScopeItems,
      scopeIsLoading: scopeLoading,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "What's your pace or deadline?",
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set a goal, or skip for now.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          _mode == 'pace'
              ? paceCard
              : _blurInactiveGoalOption(
                  context: context,
                  hint: l10n.addTrackGoalTapToUsePace,
                  onTap: () => setState(() => _mode = 'pace'),
                  child: paceCard,
                ),
          const SizedBox(height: 12),
          _mode == 'deadline'
              ? deadlineCard
              : _blurInactiveGoalOption(
                  context: context,
                  hint: l10n.addTrackGoalTapToUseDeadline,
                  onTap: () => unawaited(_activateDeadlineMode()),
                  child: deadlineCard,
                ),
          const Spacer(),
          FilledButton(
            onPressed: _continue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => widget.onComplete(null),
            child: const Text('Skip for now'),
          ),
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
    required this.selectedProgram,
    required this.onComplete,
  });

  final String programName;
  final CurriculumId curriculumId;
  final LearningProgramData? selectedProgram;
  final ValueChanged<String?> onComplete;

  @override
  ConsumerState<_StartingPositionStep> createState() =>
      _StartingPositionStepState();
}

class _StartingPositionStepState extends ConsumerState<_StartingPositionStep> {
  // Calendar-program mode (date offset picker).
  int _offsetDays = 0;
  bool _calendarLoading = false;
  String? _calendarProgramKey;
  CalendarProgramEntry? _calendarEntry;

  bool get _isCalendarProgram =>
      widget.selectedProgram?.isCalendarProgram ?? false;

  DateTime get _selectedDate => DateTime.now().add(Duration(days: _offsetDays));

  Future<void> _refreshCalendarEntry() async {
    if (!_isCalendarProgram || _calendarProgramKey == null) return;
    setState(() => _calendarLoading = true);
    try {
      final service = ref.read(calendarProgramServiceProvider);
      final entry = await service.getEntry(_calendarProgramKey!, _selectedDate);
      if (!mounted) return;
      setState(() => _calendarEntry = entry);
    } finally {
      if (mounted) {
        setState(() => _calendarLoading = false);
      }
    }
  }

  String? _resolveCalendarProgramKey() {
    final program = widget.selectedProgram;
    if (program == null) return null;
    final apiKey = program.apiProgramKey;
    if (apiKey == null || apiKey.isEmpty) {
      assert(
        !program.isCalendarProgram,
        'Calendar program ${program.name} has null/empty apiProgramKey — '
        'every is_calendar_program seed must set api_program_key to a '
        'CalendarProgramDefinition.id',
      );
      return null;
    }
    final resolved =
        CalendarProgramRegistry.byId(apiKey)?.id ??
        CalendarProgramRegistry.byApiKey(apiKey)?.id ??
        CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
    assert(
      resolved != null,
      'Calendar program ${program.name} apiProgramKey="$apiKey" did not '
      'resolve to any CalendarProgramRegistry entry. Update '
      'learning_program_seeds.dart so api_program_key matches a '
      'CalendarProgramDefinition.id.',
    );
    return resolved;
  }

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
    if (_isCalendarProgram) {
      _calendarProgramKey = _resolveCalendarProgramKey();
      unawaited(_refreshCalendarEntry());
      _loading = false;
    } else {
      _loadContent();
    }
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
      final containerList = containers.values.toList();
      final defaultContainer = containerList.isNotEmpty
          ? containerList.first
          : null;
      final defaultLeaves = defaultContainer == null
          ? <ContentItem>[]
          : items.where((item) {
              if (!item.isLeaf) return false;
              if (defaultContainer.level2 != null) {
                return item.level2 == defaultContainer.level2;
              }
              return item.level1 == defaultContainer.level1;
            }).toList();
      setState(() {
        _allItems = items;
        _containers = containerList;
        _selectedContainer = defaultContainer;
        _leaves = defaultLeaves;
        _selectedLeaf = defaultLeaves.isNotEmpty ? defaultLeaves.first : null;
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
    if (_isCalendarProgram) {
      return _buildCalendarOffsetMode(context);
    }

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

  Widget _buildCalendarOffsetMode(BuildContext context) {
    final theme = Theme.of(context);
    final date = _selectedDate;
    final weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdayNames[date.weekday - 1];
    final month = monthNames[date.month - 1];
    final dateLabel = '$weekday, $month ${date.day}';
    final offsetLabel = switch (_offsetDays) {
      0 => 'Today',
      < 0 => 'Day $_offsetDays',
      _ => 'Day +$_offsetDays',
    };
    final directionLabel = switch (_offsetDays) {
      > 0 => 'FORWARD',
      < 0 => 'BACKWARDS',
      _ => 'TODAY',
    };
    final absDays = _offsetDays.abs();
    final daysLabel = absDays == 1 ? '1 Day' : '$absDays Days';
    final canStart = _calendarEntry != null && !_calendarLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Starting Position',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Can start up to 30 days back/forward from today',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: Color(0xFFE6E8FF),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 28,
                          color: AppTheme.brandBlueDeep,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'TARGET DATE',
                        style: theme.textTheme.titleSmall?.copyWith(
                          letterSpacing: 1.1,
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppTheme.brandBlueDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_calendarLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_calendarEntry != null)
                        Column(
                          children: [
                            Builder(
                              builder: (context) {
                                final hebrewOnly = ref.watch(
                                  hebrewTermsScriptProvider,
                                );
                                final refLabel =
                                    hebrewOnly &&
                                        _calendarEntry!.todayRefHe.isNotEmpty
                                    ? _calendarEntry!.todayRefHe
                                    : _calendarEntry!.todayRef;
                                return Text(
                                  refLabel,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.brandInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final hebrewOnly = ref.watch(
                                  hebrewTermsScriptProvider,
                                );
                                final label = hebrewOnly
                                    ? _calendarEntry!.displayNameHe
                                    : _calendarEntry!.displayNameEn;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4E2C5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF6A4A13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      else
                        Text(
                          'No local calendar entry found for this date.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -14,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF707D),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      offsetLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE7EAF1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: _offsetDays <= -30
                        ? null
                        : () {
                            setState(() => _offsetDays -= 1);
                            unawaited(_refreshCalendarEntry());
                          },
                    child: Ink(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 30,
                        color: _offsetDays <= -30
                            ? AppTheme.brandInkMuted.withValues(alpha: 0.45)
                            : AppTheme.brandBlueDeep,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _offsetDays == 0 ? 'Today' : daysLabel,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            directionLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              letterSpacing: 1.1,
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: _offsetDays >= 30
                        ? null
                        : () {
                            setState(() => _offsetDays += 1);
                            unawaited(_refreshCalendarEntry());
                          },
                    child: Ink(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 30,
                        color: _offsetDays >= 30
                            ? AppTheme.brandInkMuted.withValues(alpha: 0.45)
                            : AppTheme.brandBlueDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton.tonal(
            onPressed: () {
              setState(() => _offsetDays = 0);
              unawaited(_refreshCalendarEntry());
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: const Color(0xFFE9EBF1),
              foregroundColor: AppTheme.brandInk,
            ),
            child: const Text('Use Today'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: canStart
                ? () => widget.onComplete(
                    'offset:$_offsetDays|ref:${_calendarEntry!.todayRef}',
                  )
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Start Here'),
                SizedBox(width: 8),
                Icon(Icons.rocket_launch_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
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
    _ChazaraPreset(label: 'Learn Only', delays: []),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.headerTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.headerSubtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < _presets.length; i++)
                            SizedBox(
                              width: cardWidth,
                              child: _ReviewPresetCard(
                                title: _presets[i].label,
                                subtitle: _presetDescription(i),
                                icon: _presetIcon(i),
                                isSelected: _selectedPresetIndex == i,
                                onTap: () => _selectPreset(i),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedPresetIndex == -1
                            ? AppTheme.brandBlueBright
                            : const Color(0xFFE9ECF2),
                        width: _selectedPresetIndex == -1 ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _selectCustom,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Color(0xFFF9E4C8),
                                  child: Icon(
                                    Icons.settings_suggest_rounded,
                                    size: 16,
                                    color: Color(0xFF7D5411),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Custom Cycle',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E9FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_customDelays.length} Sessions',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: AppTheme.brandBlueDeep,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < _customDelays.length; i++)
                                  _CustomDayEditorChip(
                                    day: _customDelays[i],
                                    accentColor: _delayAccent(i),
                                    onMinus: () {
                                      _selectCustom();
                                      if (_customDelays[i] > 1) {
                                        _updateCustomRound(
                                          i,
                                          _customDelays[i] - 1,
                                        );
                                      }
                                    },
                                    onPlus: () {
                                      _selectCustom();
                                      _updateCustomRound(
                                        i,
                                        _customDelays[i] + 1,
                                      );
                                    },
                                    onRemove: _customDelays.length > 1
                                        ? () {
                                            _selectCustom();
                                            _removeCustomRound(i);
                                          }
                                        : null,
                                  ),
                                if (_customDelays.length < 5)
                                  _AddRoundChip(
                                    onTap: () {
                                      _selectCustom();
                                      _addCustomRound();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _skip,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE4E5E9),
              foregroundColor: AppTheme.brandInk,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Skip (no review)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _confirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _presetDescription(int index) {
    return switch (index) {
      0 => 'No scheduled reviews.',
      1 => 'Review next morning.',
      2 => 'The recommended starter.',
      3 => 'Full mastery cycle.',
      _ => '',
    };
  }

  IconData _presetIcon(int index) {
    return switch (index) {
      0 => Icons.visibility_off_rounded,
      1 => Icons.event_available_rounded,
      2 => Icons.auto_awesome_rounded,
      3 => Icons.insights_rounded,
      _ => Icons.schedule_rounded,
    };
  }

  Color _delayAccent(int index) {
    return switch (index % 3) {
      0 => AppTheme.brandBlueBright,
      1 => const Color(0xFFFF6C78),
      _ => const Color(0xFFAA7B36),
    };
  }
}

class _ReviewPresetCard extends StatelessWidget {
  const _ReviewPresetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const selectedGradient = LinearGradient(
      colors: [AppTheme.brandBlueDeep, AppTheme.brandBlueBright],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isSelected ? selectedGradient : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected ? AppTheme.brandBlueDeep : const Color(0xFFE9ECF2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isSelected
                      ? const Color(0x33FFFFFF)
                      : const Color(0xFFE9ECF2),
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected ? Colors.white : AppTheme.brandBlueDeep,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isSelected ? Colors.white : AppTheme.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.brandInkMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomDayEditorChip extends StatelessWidget {
  const _CustomDayEditorChip({
    required this.day,
    required this.accentColor,
    required this.onMinus,
    required this.onPlus,
    this.onRemove,
  });

  final int day;
  final Color accentColor;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 5),
              color: Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'DAYS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TinyCircleButton(icon: Icons.remove, onTap: onMinus),
              const SizedBox(width: 8),
              _TinyCircleButton(icon: Icons.add, onTap: onPlus),
            ],
          ),
          if (onRemove != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddRoundChip extends StatelessWidget {
  const _AddRoundChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD1D5DE),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: AppTheme.brandInkMuted),
                  Text(
                    'ADD NEW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyCircleButton extends StatelessWidget {
  const _TinyCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F3F7),
          border: Border.all(color: const Color(0xFFDDE2EB)),
        ),
        child: Icon(icon, size: 14, color: AppTheme.brandInkMuted),
      ),
    );
  }
}
