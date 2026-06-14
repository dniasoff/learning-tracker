import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_bulk_mark.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara_readonly.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_scope.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_starting_position.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/curriculum_picker_step.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/program_selection_step.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TS-11: Computes the display denominator for the "STEP n OF N" indicator.
///
/// On the curriculum step ([currentIndex] == 0), the program step has not been
/// confirmed yet, so it is excluded from [fullStepCount] to prevent the total
/// jumping to an inflated value before the user has made any choice.
///
/// Parameters:
/// - [currentIndex]: 0-based index of the current step.
/// - [fullStepCount]: total steps including any program step.
/// - [hasProgramStep]: whether a program step is in the active steps list.
/// - [programConfirmed]: whether the user has already confirmed a program choice.
int computeWizardStepTotal({
  required int currentIndex,
  required int fullStepCount,
  required bool hasProgramStep,
  required bool programConfirmed,
}) {
  if (currentIndex == 0 && hasProgramStep && !programConfirmed) {
    // Exclude the program step from the denominator on the curriculum step.
    return fullStepCount - 1;
  }
  return fullStepCount;
}

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

// ---------------------------------------------------------------------------
// Sealed animation-state machine.
//
// Replaces two booleans (_isAnimating + _pendingAdvance) that formed an
// implicit tri-state:
//   idle                  — no page animation in flight
//   animating             — page slide in progress, no queued advance
//   animatingWithPending  — page slide in progress AND another advance
//                           was requested mid-animation; run it on settle
// ---------------------------------------------------------------------------
sealed class _AnimState {
  const _AnimState();
}

final class _AnimIdle extends _AnimState {
  const _AnimIdle();
}

final class _Animating extends _AnimState {
  const _Animating();
}

final class _AnimatingWithPending extends _AnimState {
  const _AnimatingWithPending();
}

// ---------------------------------------------------------------------------

class _AddTrackFlowState extends ConsumerState<AddTrackFlow> {
  AddTrackState _state = const AddTrackState();
  late final PageController _pageController;
  _AnimState _animState = const _AnimIdle();
  bool _isFinishing = false;

  /// D2: inline error message for a failed track save. Rendered as a prominent
  /// banner within the wizard content (above the step's primary action) rather
  /// than via ScaffoldMessenger — the app-shell-level ScaffoldMessenger queue
  /// lives above the wizard's route, so its snackbars leak across route pushes.
  /// An inline message is scoped to the wizard and cannot leak. Cleared on any
  /// step change.
  String? _errorMessage;

  /// Whether a program was selected (vs self-paced).
  bool get _isProgramTrack => _state.programId != null;

  /// Whether the selected program defines review/chazara stages.
  bool get _programHasChazara {
    final program = _state.selectedProgram;
    if (program == null) return false;
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
    return ref
        .read(learningProgramRepositoryProvider)
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
      selectedProgram = ref
          .read(learningProgramRepositoryProvider)
          .getProgramById(programId);
    }

    final programsExistForResume =
        curriculum != null &&
        ref
            .read(learningProgramRepositoryProvider)
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
    if (_animState is _Animating) {
      _animState = const _AnimatingWithPending();
      return;
    }
    if (_animState is _AnimatingWithPending) {
      // Already queued — no-op; the pending flag is already set.
      return;
    }
    final currentIndex = _currentIndex;
    if (currentIndex < _activeSteps.length - 1) {
      final nextStep = _activeSteps[currentIndex + 1];
      setState(() {
        _state = _state.copyWith(currentStep: nextStep);
        _animState = const _Animating();
        _errorMessage = null; // D2: clear inline error on step change.
      });
      _pageController
          .nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            final hadPending = _animState is _AnimatingWithPending;
            _animState = const _AnimIdle();
            if (hadPending && mounted) {
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
        _errorMessage = null; // D2: clear inline error on step change.
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
      final l10n = AppLocalizations.of(context)!;
      final shouldExit = await showAppConfirmDialog(
        context: context,
        title: l10n.exitTrackSetupTitle,
        message: l10n.exitTrackSetupMessage,
        confirmLabel: l10n.actionExit,
        cancelLabel: l10n.actionCancel,
        icon: Icons.exit_to_app_rounded,
        destructive: true,
      );
      if (!shouldExit) return;
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

    // D1: widget.profileId may be 0 if selectedProfileIdProvider was null
    // at build time (cold start / force-stop before ProfileGuard ran).
    // Re-read the current activeProfileId so the write uses the correct FK.
    final effectiveProfileId = widget.profileId != 0
        ? widget.profileId
        : ref.read(activeProfileIdProvider);

    try {
      final creationService = ref.read(trackCreationServiceProvider);
      await creationService.createTrack(
        result: result,
        profileId: effectiveProfileId,
      );

      await invalidateAfterTrackDataChange(ref, effectiveProfileId);

      if (!_isProgramTrack && priorSelections != null) {
        unawaited(
          _applySelfPacedPriorCompletions(
            priorSelections,
            profileId: effectiveProfileId,
          ).then(
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
    } on TutorWriteException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tutorPermissionDenied),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'track_creation_failed',
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      // D2: surface the failure INLINE within the wizard rather than via the
      // app-shell ScaffoldMessenger. The messenger's snackbar queue lives above
      // this wizard's route, so a snackbar shown here persists (leaks) onto the
      // next route after the wizard pops. An inline message is scoped to the
      // wizard's own widget tree and disappears with it. Retry is the step's
      // primary action (e.g. "Start Here"); the banner also offers a retry tap.
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorSaveTrackFailed;
      });
    } finally {
      _isFinishing = false;
    }
  }

  Future<({int itemCount, int completionCount})>
  _applySelfPacedPriorCompletions(
    Set<HierarchySelection> selections, {
    required int profileId,
  }) async {
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
      profileId: profileId,
    );

    // Refresh dashboard/progress/task views immediately.
    await onTrackChanged(ref, profileId);

    return (
      itemCount: completion.itemCount,
      completionCount: completion.completionCount,
    );
  }

  String _getSmartDefault() {
    if (_state.programName != null) return _state.programName!;
    if (_state.scopeSelections != null && _state.scopeSelections!.isNotEmpty) {
      // R1-(1): raw scope values are Sefaria English translations (e.g. "Genesis").
      // Transliterate through the curriculum label renderer so the toast
      // shows "Bereishis"/"Bereshit" instead of "Genesis".
      final rawValue = _state.scopeSelections!.last.value;
      final variant = ref.read(currentTransliterationVariantProvider);
      return CurriculumLabels.transliterateNamedValue(
        rawValue,
        variant: variant,
      );
    }
    final c = _state.curriculumId;
    if (c == null) return '';
    return curriculumLabelText(ref, curriculum: c);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;
    // TS-11: on the curriculum step, exclude the program step from the total
    // so the denominator doesn't jump to 7 before any program is confirmed.
    final displayTotal = computeWizardStepTotal(
      currentIndex: _currentIndex,
      fullStepCount: steps.length,
      hasProgramStep: steps.contains(AddTrackStep.program),
      programConfirmed: _state.programId != null,
    );
    final progress = _currentIndex.clamp(0, steps.length) / steps.length;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
                            l10n.addTrackStepCounter(
                              _currentIndex + 1,
                              displayTotal,
                            ),
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
              // D2: inline save-error banner — scoped to the wizard, no
              // ScaffoldMessenger, so it cannot leak across routes.
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusErrorSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.chartRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.chartRed,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.chartRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _errorMessage = null);
                            unawaited(_finishFlow());
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.chartRed,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.actionRetry,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
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
      // R1-(7): pass the previously-chosen scope so Back+Forward navigation
      // restores the section selection instead of discarding it.
      initialSelections: _state.scopeSelections,
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
      final program = _state.selectedProgram!;
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
        // B1: pass the program's PRESET so its learn + chazara stages are
        // actually seeded. Passing null left wizardResult null, so
        // TrackCreationService deleted the track's stages and never re-applied
        // them — the program track ended up with ZERO stages (dead: no daily,
        // overdue, or chazara tasks), and re-configuring an existing track
        // wiped its schedule. _applyPreset reads the program's stagesConfig.
        onContinue: () => _onChazaraComplete(
          LearningProcessWizardResult(
            wizardResult: WizardResult(
              curriculumId: _state.curriculumId!,
              choice: WizardChoice.preset,
              programId: _state.programId,
            ),
          ),
        ),
      );
    }

    // Program with OPEN chazara → offer optional inline setup
    // Self-paced → inline setup
    // Both paths use ChazaraInlineSetup; differ only in header copy.
    final l10n = AppLocalizations.of(context)!;
    final chazaraTerm = domainTermLabels(ref).chazara;
    final headerTitle = _isProgramTrack
        ? l10n.addTrackChazaraStepTitle(chazaraTerm)
        : l10n.addTrackChazaraStepQuestion(chazaraTerm);
    final headerSubtitle = _isProgramTrack
        ? l10n.chazaraProgramNoReviewSubtitle(_state.programName ?? '')
        : l10n.chazaraSelfPacedSubtitle(chazaraTerm);

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
      // TS-2 fix: pass the wizard's scope selections so the step computes
      // item count from the selected scope, not the full-curriculum total.
      scopeSelections: _state.scopeSelections,
      // TS-10 fix: pass the previously-set goal so Back+Forward navigation
      // restores the deadline/pace choice the user already made.
      initialGoal: _state.goalResult,
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
      selectedProgram: _state.selectedProgram,
      onComplete: _onStartingPositionComplete,
    );
  }
}
