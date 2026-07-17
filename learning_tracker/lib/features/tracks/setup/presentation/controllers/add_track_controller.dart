import 'dart:convert';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/controllers/add_track_flow_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'add_track_controller.g.dart';

// ── SharedPreferences keys ────────────────────────────────────────────────────

const _kStep = 'add_track_step';
const _kCurriculum = 'add_track_curriculum';
const _kScope = 'add_track_scope';
const _kProgram = 'add_track_program';
const _kProgramName = 'add_track_program_name';
const _kStudyDays = 'add_track_study_days';
const _kLabel = 'add_track_label';

// ── AddTrackController ────────────────────────────────────────────────────────

/// State-machine controller for the Add Track wizard.
///
/// Manages [AddTrackFlowState] (navigation) and the accumulated
/// [AddTrackState] form data as the user progresses through steps.
///
/// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
/// separate invocations (onboarding vs settings) maintain independent state.
@riverpod
class AddTrackController extends _$AddTrackController {
  @override
  AddTrackFlowState build(int profileId, {required bool isOnboarding}) {
    // Start at curriculum-choice (the first real step).
    return const CurriculumChoiceState(formData: AddTrackState());
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Attempt to restore a saved wizard session from SharedPreferences.
  ///
  /// Called by [AddTrackFlowScreen] after the first frame so it does not
  /// block the initial render.
  Future<void> tryRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final stepIndex = prefs.getInt(_kStep);
    if (stepIndex == null) return; // Nothing saved.

    final curriculumKey = prefs.getString(_kCurriculum);
    final scopeJson = prefs.getString(_kScope);
    final programId = prefs.getInt(_kProgram);
    final programName = prefs.getString(_kProgramName);
    final studyDaysJson = prefs.getString(_kStudyDays);
    final label = prefs.getString(_kLabel);

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

    final formData = AddTrackState(
      curriculumId: curriculum,
      scopeSelections: scopes,
      programId: programId,
      programName: programName,
      studyDays: studyDays,
      trackLabel: label,
    );

    // Restore to the appropriate navigation state based on saved step index.
    // Clamp to valid range and fall back to curriculumChoice on unknown values.
    final clamped = stepIndex.clamp(0, 6);
    state = _navStateFromIndex(clamped, formData);
  }

  /// Persists the wizard's current step + form data so it can be restored.
  ///
  /// AUD-core-preferences-04 (EH-2): callers ([_advance], [goBack],
  /// [onConfirmationComplete]) fire this fire-and-forget (no `await`, no
  /// `unawaited()`) so navigation is never blocked on disk I/O — which means
  /// an exception here would previously become an unobserved Future
  /// rejection. The whole body is wrapped so this method's Future NEVER
  /// rejects: a write failure is caught and logged instead. The wizard's
  /// in-memory `state` (the actual navigation source of truth) is
  /// unaffected either way — only the save-for-later-restore snapshot is
  /// lost, and now that loss is at least diagnosable from Send Diagnostic
  /// Logs instead of silently vanishing.
  Future<void> _persist() async {
    try {
      final form = state.formData;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kStep, _navIndex(state));
      if (form.curriculumId != null) {
        await prefs.setString(_kCurriculum, form.curriculumId!.storageKey);
      }
      if (form.scopeSelections != null) {
        await prefs.setString(
          _kScope,
          jsonEncode(
            form.scopeSelections!
                .map((s) => {'level': s.level, 'value': s.value})
                .toList(),
          ),
        );
      }
      if (form.programId != null) {
        await prefs.setInt(_kProgram, form.programId!);
      }
      if (form.programName != null) {
        await prefs.setString(_kProgramName, form.programName!);
      }
      if (form.studyDays != null) {
        await prefs.setString(
          _kStudyDays,
          jsonEncode(form.studyDays!.map((k, v) => MapEntry(k.toString(), v))),
        );
      }
      if (form.trackLabel != null) {
        await prefs.setString(_kLabel, form.trackLabel!);
      }
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'add_track_wizard_persist_failed',
        exception: e,
        stackTrace: st,
      );
    }
  }

  Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kStep,
      _kCurriculum,
      _kScope,
      _kProgram,
      _kProgramName,
      _kStudyDays,
      _kLabel,
    ]) {
      await prefs.remove(key);
    }
  }

  // ── Transition helpers ───────────────────────────────────────────────────────

  bool get _isProgramTrack => state.formData.programId != null;

  bool get _hasProgramStepForCurrentCurriculum {
    final id = state.formData.curriculumId;
    if (id == null) return false;
    return AddTrackFlowStateX.hasProgramsForCurriculum(id);
  }

  /// Advance to the next logical navigation state.
  void _advance(AddTrackState updatedForm) {
    final hasProgramStep =
        updatedForm.curriculumId != null &&
        AddTrackFlowStateX.hasProgramsForCurriculum(updatedForm.curriculumId!);
    state = switch (state) {
      CurriculumChoiceState() =>
        hasProgramStep
            ? ProgramChoiceState(formData: updatedForm)
            : (updatedForm.programId != null
                  ? StudyDaysState(formData: updatedForm)
                  : ScopeChoiceState(formData: updatedForm)),
      ProgramChoiceState() =>
        updatedForm.programId != null
            ? StudyDaysState(formData: updatedForm)
            : ScopeChoiceState(formData: updatedForm),
      ScopeChoiceState() => StudyDaysState(formData: updatedForm),
      StudyDaysState() => StagesChoiceState(formData: updatedForm),
      StagesChoiceState() =>
        updatedForm.programId != null
            ? ConfirmationState(formData: updatedForm)
            : GoalChoiceState(formData: updatedForm),
      GoalChoiceState() => ConfirmationState(formData: updatedForm),
      ConfirmationState() =>
        state, // terminal — submission moves to CompleteState
      CompleteState() => state,
    };
    _persist();
  }

  /// Go back one step.
  ///
  /// Returns `true` if a back-navigation occurred,
  /// `false` if already on the first step (caller should exit the flow).
  bool goBack() {
    final form = state.formData;
    final prev = switch (state) {
      CurriculumChoiceState() => null, // exit the flow
      ProgramChoiceState() => CurriculumChoiceState(formData: form),
      ScopeChoiceState() =>
        _hasProgramStepForCurrentCurriculum
            ? ProgramChoiceState(formData: form)
            : CurriculumChoiceState(formData: form),
      StudyDaysState() =>
        _isProgramTrack
            ? (_hasProgramStepForCurrentCurriculum
                  ? ProgramChoiceState(formData: form)
                  : CurriculumChoiceState(formData: form))
            : ScopeChoiceState(formData: form),
      StagesChoiceState() =>
        _isProgramTrack
            ? StudyDaysState(formData: form)
            : StudyDaysState(formData: form),
      GoalChoiceState() => StagesChoiceState(formData: form),
      ConfirmationState() =>
        _isProgramTrack
            ? StagesChoiceState(formData: form)
            : GoalChoiceState(formData: form),
      CompleteState() => null, // already done
    };
    if (prev == null) return false;
    state = prev;
    _persist();
    return true;
  }

  // ── Step callbacks ────────────────────────────────────────────────────────

  /// User selected a curriculum.
  void onCurriculumSelected(CurriculumId curriculum) {
    // Clear stale program state when switching curricula.
    final updated = state.formData.copyWith(
      curriculumId: curriculum,
      contentActivated: true,
      programId: null,
      programName: null,
      selectedProgram: null,
    );
    _advance(updated);
  }

  /// User selected (or skipped) a learning program.
  void onProgramSelected(
    int? programId,
    String? programName,
    LearningProgramData? program,
  ) {
    final updated = state.formData.copyWith(
      programId: programId,
      programName: programName,
      selectedProgram: program,
      // Clear scope selections when a program is selected (program defines scope).
      scopeSelections: programId != null
          ? null
          : state.formData.scopeSelections,
      // Auto-fill study days for program tracks (step is skipped).
      studyDays: programId != null
          ? Map<int, String>.from(kDefaultStudyDays)
          : state.formData.studyDays,
    );
    _advance(updated);
  }

  /// User completed scope selection.
  void onScopeComplete(List<ScopeEntry>? scopes) {
    final updated = state.formData.copyWith(scopeSelections: scopes);
    _advance(updated);
  }

  /// User completed study-days selection.
  void onStudyDaysComplete(Map<int, String> studyDays) {
    final updated = state.formData.copyWith(studyDays: studyDays);
    _advance(updated);
  }

  /// User completed chazara/stages setup.
  void onStagesComplete(LearningProcessWizardResult? wizardResult) {
    final updated = state.formData.copyWith(wizardResult: wizardResult);
    _advance(updated);
  }

  /// User completed goal setup.
  void onGoalComplete(GoalEntity? goalResult) {
    final updated = state.formData.copyWith(goalResult: goalResult);
    _advance(updated);
  }

  /// User completed the confirmation step.
  ///
  /// Delegates actual track creation to the calling screen (which has a
  /// `BuildContext` for dialogs). The screen calls [submit] after any
  /// necessary confirmation dialogs.
  void onConfirmationComplete(
    BulkMarkIntent? bulkMarkResult,
    String? startingRef,
  ) {
    final updated = state.formData.copyWith(
      bulkMarkResult: bulkMarkResult,
      startingRef: startingRef,
    );
    // Move form data so the screen can read it before submission.
    state = ConfirmationState(formData: updated);
    _persist();
  }

  // ── Submission ────────────────────────────────────────────────────────────

  /// Build the [AddTrackResult] from accumulated form data.
  AddTrackResult buildResult() {
    final form = state.formData;
    return AddTrackResult(
      curriculumId: form.curriculumId!,
      label: _smartLabel(form),
      programId: form.programId,
      programName: form.programName,
      scopeSelections: form.scopeSelections,
      studyDays: form.studyDays ?? kDefaultStudyDays,
      wizardResult: form.wizardResult,
      goalResult: form.goalResult,
      bulkMarkResult: form.bulkMarkResult,
      startingRef: form.startingRef,
    );
  }

  /// Mark the flow as complete with the given result.
  void markComplete(AddTrackResult result) {
    state = CompleteState(formData: state.formData, result: result);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _smartLabel(AddTrackState form) {
    if (form.programName != null) return form.programName!;
    if (form.scopeSelections != null && form.scopeSelections!.isNotEmpty) {
      final c = form.curriculumId;
      // F-05/F-21: when ALL top-level items were selected via "Select all in
      // this list", return the curriculum name instead of the last seder value
      // (which would show e.g. "Seder Taharos" even though the full curriculum
      // was chosen).
      if (c != null) {
        final level1Selected = form.scopeSelections!
            .where((s) => s.level == 1)
            .map((s) => s.value)
            .toSet();
        final content = ref.read(curriculumContentProvider(c)).asData?.value;
        if (content != null && level1Selected.isNotEmpty) {
          final totalLevel1 = content.map((item) => item.level1).toSet().length;
          if (level1Selected.length >= totalLevel1) {
            return c.storageKey;
          }
        }
      }
      return form.scopeSelections!.last.value;
    }
    // Use storageKey as a locale-neutral fallback. The screen can later
    // override this with a locale-aware label via CurriculumLabel/LabelRenderer.
    return form.curriculumId?.storageKey ?? '';
  }

  static AddTrackFlowState _navStateFromIndex(int index, AddTrackState form) {
    return switch (index) {
      0 => CurriculumChoiceState(formData: form),
      1 => ProgramChoiceState(formData: form),
      2 => ScopeChoiceState(formData: form),
      3 => StudyDaysState(formData: form),
      4 => StagesChoiceState(formData: form),
      5 => GoalChoiceState(formData: form),
      _ => ConfirmationState(formData: form),
    };
  }

  static int _navIndex(AddTrackFlowState s) {
    return switch (s) {
      CurriculumChoiceState() => 0,
      ProgramChoiceState() => 1,
      ScopeChoiceState() => 2,
      StudyDaysState() => 3,
      StagesChoiceState() => 4,
      GoalChoiceState() => 5,
      ConfirmationState() => 6,
      CompleteState() => 6,
    };
  }
}
