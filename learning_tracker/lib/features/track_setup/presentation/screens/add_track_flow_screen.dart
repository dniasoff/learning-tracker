import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart'
    show kDefaultStudyDays;
import 'package:learning_tracker/features/track_setup/presentation/controllers/add_track_controller.dart';
import 'package:learning_tracker/features/track_setup/presentation/controllers/add_track_flow_state.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/curriculum_picker_step.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/program_selection_step.dart';

/// Thin shell screen for the Add Track wizard (Story 26.9, UX-DR17, T2.1).
///
/// Reads [AddTrackController] for navigation state and delegates each step
/// to the corresponding step widget in `add_track_flow.dart`.
/// < 300 lines by design; step implementations extracted in Story 26.10.
class AddTrackFlowScreen extends ConsumerStatefulWidget {
  const AddTrackFlowScreen({
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
  ConsumerState<AddTrackFlowScreen> createState() => _State();
}

class _State extends ConsumerState<AddTrackFlowScreen> {
  bool _isFinishing = false;

  AddTrackControllerProvider get _provider => addTrackControllerProvider(
    widget.profileId,
    isOnboarding: widget.isOnboarding,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(_provider.notifier).tryRestore(),
    );
  }

  Future<void> _onBack() async {
    final navigated = ref.read(_provider.notifier).goBack();
    if (!navigated) await _confirmExit();
  }

  Future<void> _confirmExit() async {
    final hasData = ref.read(_provider).formData.curriculumId != null;
    if (hasData) {
      final ok = await _exitDialog();
      if (ok != true) return;
    }
    await ref.read(_provider.notifier).clearSaved();
    widget.onCancel?.call();
  }

  Future<void> _submit({SelfPacedPriorCompletionSelection? prior}) async {
    if (_isFinishing) return;
    _isFinishing = true;
    final notifier = ref.read(_provider.notifier);
    final result = notifier.buildResult();

    final activeCurricula =
        ref.read(dashboardActiveCurriculaProvider).asData?.value ?? const [];
    if (activeCurricula.contains(result.curriculumId)) {
      if (!mounted) {
        _isFinishing = false;
        return;
      }
      final ok = await _replaceDialog(result.curriculumId.storageKey);
      if (ok != true) {
        _isFinishing = false;
        return;
      }
    }

    try {
      await ref
          .read(trackCreationServiceProvider)
          .createTrack(result: result, profileId: widget.profileId);
      await invalidateAfterTrackDataChange(ref, widget.profileId);
      if (prior != null && result.programId == null)
        unawaited(_applyPrior(prior, result));
      await notifier.clearSaved();
      notifier.markComplete(result);
      widget.onComplete?.call(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save track. Please try again.'),
          action: SnackBarAction(label: 'Retry', onPressed: _submit),
        ),
      );
    } finally {
      _isFinishing = false;
    }
  }

  Future<void> _applyPrior(
    SelfPacedPriorCompletionSelection sel,
    AddTrackResult r,
  ) async {
    final svc = ref.read(bulkPriorCompletionServiceProvider);
    final hs = sel.markAll
        ? const [HierarchySelection()]
        : sel.selectedScopes
              .map(
                (s) => switch (s.level) {
                  1 => HierarchySelection(level1: s.value),
                  2 => HierarchySelection(level2: s.value),
                  3 => HierarchySelection(level3: s.value),
                  4 => HierarchySelection(level4: s.value),
                  _ => const HierarchySelection(),
                },
              )
              .toList();
    if (hs.isEmpty) return;
    final resolved = await svc.resolveSelections(
      curriculumId: r.curriculumId,
      selections: hs,
    );
    if (resolved.isEmpty) return;
    await svc.execute(
      curriculumId: r.curriculumId,
      resolvedItems: resolved,
      stageIds: const [1],
      profileId: widget.profileId,
    );
    ref.invalidate(dashboardCompletionPercentageProvider(r.curriculumId));
    ref.invalidate(dashboardLastCompletionProvider(r.curriculumId));
    ref.invalidate(progressOverviewStatsProvider);
    ref.invalidate(allDailyTasksProvider);
  }

  Future<bool?> _exitDialog() => showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (ctx) => _ExitDialog(
      () => Navigator.pop(ctx, true),
      () => Navigator.pop(ctx, false),
    ),
  );

  Future<bool?> _replaceDialog(String label) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final t = Theme.of(ctx);
      return AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: t.colorScheme.error,
          size: 32,
        ),
        title: Text('Replace your $label track?'),
        content: Text(
          'You already have a $label track. Continuing will replace its study days, scope, review schedule, and goals.',
          style: t.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: t.colorScheme.error,
              foregroundColor: t.colorScheme.onError,
            ),
            child: const Text('Replace'),
          ),
        ],
      );
    },
  );

  Widget _buildStep(AddTrackFlowState state) {
    final n = ref.read(_provider.notifier);
    final f = state.formData;
    return switch (state) {
      CurriculumChoiceState() =>
        ref
            .watch(dashboardActiveCurriculaProvider)
            .when(
              data: (l) => CurriculumPickerStep(
                onSelected: n.onCurriculumSelected,
                isOnboarding: widget.isOnboarding,
                existingTrackCurricula: l.toSet(),
              ),
              loading: () => CurriculumPickerStep(
                onSelected: n.onCurriculumSelected,
                isOnboarding: widget.isOnboarding,
              ),
              error: (_, __) => CurriculumPickerStep(
                onSelected: n.onCurriculumSelected,
                isOnboarding: widget.isOnboarding,
              ),
            ),
      ProgramChoiceState() => ProgramSelectionStep(
        curriculumId: f.curriculumId!,
        onSelected: n.onProgramSelected,
      ),
      ScopeChoiceState() => ScopeStepContent(
        curriculumId: f.curriculumId!,
        onComplete: n.onScopeComplete,
      ),
      StudyDaysState() =>
        f.programId != null
            ? StudyDaysReadOnly(
                programName: f.programName ?? '',
                onContinue: () =>
                    n.onStudyDaysComplete(Map.from(kDefaultStudyDays)),
              )
            : StudyDaysEditable(onComplete: n.onStudyDaysComplete),
      StagesChoiceState() => _stagesStep(f, n),
      GoalChoiceState() => SelfPacedGoalStep(
        curriculumId: f.curriculumId!,
        studyDays: f.studyDays ?? kDefaultStudyDays,
        onComplete: n.onGoalComplete,
      ),
      ConfirmationState() =>
        f.programId != null
            ? StartingPositionStep(
                programName: f.programName ?? '',
                curriculumId: f.curriculumId!,
                selectedProgram: f.selectedProgram as LearningProgramData?,
                onComplete: (r) {
                  n.onConfirmationComplete(null, r);
                  unawaited(_submit());
                },
              )
            : SelfPacedPriorProgressStep(
                curriculumId: f.curriculumId!,
                scopeSelections: f.scopeSelections,
                onSkip: () => unawaited(_submit()),
                onMarkCompleted: (s) => unawaited(_submit(prior: s)),
              ),
      CompleteState() => const SizedBox.shrink(),
    };
  }

  Widget _stagesStep(AddTrackState f, AddTrackController n) {
    final isProg = f.programId != null;
    if (isProg && _hasChazara(f)) {
      return ProgramChazaraReadOnlyStep(
        stagesConfig: (f.selectedProgram as LearningProgramData).stagesConfig,
        programName: f.programName ?? '',
        onComplete: n.onStagesComplete,
      );
    }
    return ChazaraInlineSetup(
      curriculumId: f.curriculumId!,
      headerTitle: isProg ? 'Add Review?' : 'How do you want to review?',
      headerSubtitle: isProg
          ? '${f.programName} doesn\'t include a review schedule. Set one up now or skip.'
          : 'Pick a preset or build your own חזרה schedule.',
      onComplete: n.onStagesComplete,
    );
  }

  bool _hasChazara(AddTrackState f) {
    final p = f.selectedProgram;
    if (p is! LearningProgramData) return false;
    try {
      final s = jsonDecode(p.stagesConfig) as List<dynamic>;
      return s.any(
        (x) => (x as Map<String, dynamic>)['stage'].toString() != 'learn',
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: ColoredBox(
        color: const Color(0xFFF4F5F7),
        child: SafeArea(
          child: Column(
            children: [
              if (state.totalSteps > 1)
                _ProgressHeader(
                  stepNumber: state.stepNumber,
                  totalSteps: state.totalSteps,
                  progress: state.progressFraction,
                  theme: theme,
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey(state.runtimeType),
                    child: _buildStep(state),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.stepNumber,
    required this.totalSteps,
    required this.progress,
    required this.theme,
  });

  final int stepNumber;
  final int totalSteps;
  final double progress;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              'STEP $stepNumber OF $totalSteps',
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
  );
}

class _ExitDialog extends StatelessWidget {
  const _ExitDialog(this.onExit, this.onCancel);

  final VoidCallback onExit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
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
              'Are you sure you want to exit?\nYour setup progress will be lost.',
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
                onPressed: onExit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('Exit'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onCancel,
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
  }
}
