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
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
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
/// The denominator is kept stable so it never changes as the user moves between
/// steps. The program step is excluded from [fullStepCount] only while no
/// curriculum has been selected yet — i.e. before the user taps any curriculum
/// tile. The instant a curriculum is chosen (even while still on step 0), the
/// full count is shown so the total does not jump on the slide to step 1.
///
/// Parameters:
/// - [currentIndex]: 0-based index of the current step.
/// - [fullStepCount]: total steps including any program step.
/// - [hasProgramStep]: whether a program step is in the active steps list.
/// - [curriculumSelected]: whether the user has already picked a curriculum.
int computeWizardStepTotal({
  required int currentIndex,
  required int fullStepCount,
  required bool hasProgramStep,
  required bool curriculumSelected,
}) {
  if (currentIndex == 0 && hasProgramStep && !curriculumSelected) {
    // No curriculum chosen yet — exclude the program step so the denominator
    // does not appear inflated before any choice is made.
    return fullStepCount - 1;
  }
  return fullStepCount;
}

/// Pure, ref-free implementation of the Add-Track wizard's smart default
/// track name. Extracted from [_AddTrackFlowState._getSmartDefault] (which
/// wraps this with the `ref.watch`ed Hebrew-terms/transliteration state) so
/// it can be unit-tested directly against [AddTrackState] without a
/// `WidgetRef`/`ProviderScope` — see add_track_result_test.dart.
///
/// AUD-t-track_setup-01 / F-05/F-21/run7: always uses the curriculum label
/// for the track's default name (not the last-selected seder, e.g. "Seder
/// Taharos") so the post-creation snackbar matches the Track Management hub
/// card title, which shows the curriculum — whether the user picked the
/// whole curriculum or just a section.
String smartDefaultTrackName(
  AddTrackState state, {
  required bool useHebrewTerms,
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
}) {
  if (state.programName != null) return state.programName!;
  if (state.scopeSelections != null && state.scopeSelections!.isNotEmpty) {
    // F-05/F-21/run7: always use the curriculum label for the track's default
    // name (not the last-selected seder, e.g. "Seder Taharos") so the
    // post-creation snackbar matches the Track Management hub card title,
    // which shows the curriculum — whether the user picked the whole
    // curriculum or just a section.
    final c = state.curriculumId;
    if (c != null) {
      return curriculumLabelFor(
        c,
        useHebrewTerms: useHebrewTerms,
        variant: variant,
      );
    }
  }
  final c = state.curriculumId;
  if (c == null) return '';
  return curriculumLabelFor(
    c,
    useHebrewTerms: useHebrewTerms,
    variant: variant,
  );
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
      await creationService.createTrack(result: result);

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

  /// [profileId] is used only for post-write invalidation ([onTrackChanged])
  /// below — NOT for the bulk-mark identity itself. `service.execute()` no
  /// longer accepts a profileId (owner decision 2,
  /// `docs/firestore-rewrite-map.md`): bulk-marking always targets the
  /// CURRENTLY ACTIVE profile now. During onboarding, [profileId] here is
  /// `_createdProfileId` — a newly-created CHILD profile
  /// (`onboarding_screen.dart`'s `_ScreenPhase.addTrack` phase). It now
  /// matches `activeProfileIdProvider` at this point in the flow:
  /// `onboarding_screen.dart`'s `_onProfileCreated` selects the just-created
  /// profile (`selectedProfileIdProvider.notifier.select`) immediately after
  /// creation, before the flow ever reaches this step. See
  /// `bulk_prior_completion_service.dart`'s `execute` doc comment for the
  /// storage-layer side of the same fix.
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
    );

    // Refresh dashboard/progress/task views immediately.
    await onTrackChanged(ref, profileId);

    // onTrackChanged() above hand-invalidates the track/dashboard surfaces
    // but does not fire completionCommittedProvider, so any watcher of that
    // shared signal (e.g. journeyViewModelProvider) is missed here — the
    // same staleness class as BulkMarkScreen's entry point, which uses this
    // identical service. Fire it too so both entry points stay in sync.
    ref.read(completionCommittedProvider.notifier).increment();

    return (
      itemCount: completion.itemCount,
      completionCount: completion.completionCount,
    );
  }

  String _getSmartDefault() => smartDefaultTrackName(
    _state,
    useHebrewTerms: ref.watch(effectiveUseHebrewTermsProvider),
    variant: ref.watch(currentTransliterationVariantProvider),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = _activeSteps;
    // TS-11: once a curriculum is selected the final step count is known;
    // keep the denominator stable so it never changes mid-slide.
    final displayTotal = computeWizardStepTotal(
      currentIndex: _currentIndex,
      fullStepCount: steps.length,
      hasProgramStep: steps.contains(AddTrackStep.program),
      curriculumSelected: _state.curriculumId != null,
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
        // brandCream (not the old fixed 0xFFF4F5F7): run-9 audit — this was
        // the wizard's ENTIRE canvas hardcoded to a fixed light grey, so
        // every heading on it (already theme-aware ink, going light in
        // dark) rendered near-white-on-light-grey in dark mode.
        color: context.colors.brandCream,
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
                              color: context.colors.brandInkMuted,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).round()}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: context.colors.brandBlueDeep,
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
                          backgroundColor: context.colors.surfaceE9,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.colors.brandBlueBright,
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
                      color: context.colors.statusErrorSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.colors.chartRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: context.colors.chartRed,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.colors.chartRed,
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
                            foregroundColor: context.colors.chartRed,
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
