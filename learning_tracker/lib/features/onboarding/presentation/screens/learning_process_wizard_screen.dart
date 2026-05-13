import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/wizard_steps.dart';

// Re-export from domain layer for backward compatibility.
export 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart'
    show LearningProcessWizardResult;

/// Learning Process Wizard screen — shown per curriculum during onboarding.
///
/// Uses an [OnboardingController] to advance/retreat through a
/// [List<OnboardingStep>]. Three paths:
/// 1. Follow a program (preset)
/// 2. Custom schedule (3-step builder)
/// 3. No formal review (Learn only)
///
/// Tapping a method in [WizardChooseMethodStep] either completes immediately
/// (no-review / custom-confirm) or advances to the appropriate next step
/// (preset selection).
class LearningProcessWizardScreen extends ConsumerStatefulWidget {
  const LearningProcessWizardScreen({
    required this.curriculumId,
    required this.presets,
    required this.isChildMode,
    this.childName,
    this.skipChooseMethod = false,
    super.key,
  });

  final CurriculumId curriculumId;
  final List<LearningProgramData> presets;
  final bool isChildMode;
  final String? childName;

  /// When true, skips the initial "How do you review?" choice screen
  /// and goes directly to the custom schedule builder.
  final bool skipChooseMethod;

  @override
  ConsumerState<LearningProcessWizardScreen> createState() =>
      _LearningProcessWizardScreenState();
}

class _LearningProcessWizardScreenState
    extends ConsumerState<LearningProcessWizardScreen> {
  final _wizardData = WizardStepData();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSteps());
  }

  void _complete(LearningProcessWizardResult result) {
    Navigator.of(context).pop(result);
  }

  List<OnboardingStep> _buildSteps() {
    if (widget.skipChooseMethod) {
      // Skip directly to the custom 3-step builder.
      return [
        WizardCustomStep1(data: _wizardData),
        WizardCustomStep2(data: _wizardData),
        WizardCustomStep3(
          curriculumId: widget.curriculumId,
          data: _wizardData,
          onComplete: _complete,
        ),
      ];
    }

    return [
      WizardChooseMethodStep(
        curriculumId: widget.curriculumId,
        presets: widget.presets,
        isChildMode: widget.isChildMode,
        childName: widget.childName,
        onComplete: _complete,
      ),
      if (widget.presets.isNotEmpty)
        WizardSelectPresetStep(
          curriculumId: widget.curriculumId,
          presets: widget.presets,
          isChildMode: widget.isChildMode,
          childName: widget.childName,
          data: _wizardData,
          onComplete: _complete,
        ),
      WizardCustomStep1(data: _wizardData),
      WizardCustomStep2(data: _wizardData),
      WizardCustomStep3(
        curriculumId: widget.curriculumId,
        data: _wizardData,
        onComplete: _complete,
      ),
    ];
  }

  Future<void> _initSteps() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    await controller.init(_buildSteps());
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(onboardingControllerProvider);

    if (controllerState.steps.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentStep = controllerState.currentStep;
    final ctx = OnboardingStepContext(
      advance: () async {
        await ref.read(onboardingControllerProvider.notifier).advance();
      },
      retreat: () {
        if (controllerState.hasPrevious) {
          ref.read(onboardingControllerProvider.notifier).retreat();
        } else {
          Navigator.of(context).pop(); // Exit wizard
        }
      },
      stepIndex: controllerState.currentIndex,
      totalSteps: controllerState.steps.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: _WizardTitle(curriculumId: widget.curriculumId),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: ctx.retreat,
        ),
      ),
      body: currentStep.build(context, ref, ctx),
    );
  }
}

/// Lightweight [ConsumerWidget] for the wizard's AppBar title.
class _WizardTitle extends ConsumerWidget {
  const _WizardTitle({required this.curriculumId});

  final CurriculumId curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(curriculumLabelText(ref, curriculum: curriculumId));
  }
}
