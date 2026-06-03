// Overflow guard tests for onboarding step bodies that fill height with a
// fixed pile of content (no scroll escape valve before the fix).
//
// Each surface is rendered across the full device/text-scale matrix
// (including the small viewport × 2.0 text corner) via
// [expectNoOverflowAcrossDevices]; a RenderFlex overflow at any corner fails
// the test. The fixed bodies are now wrapped in a SingleChildScrollView so they
// scroll instead of clipping on short screens / large text.
//
// Surfaces guarded:
//   • OnboardingHandoffStep             — child-mode handoff (icon + 3 texts +
//                                         3 buttons).
//   • OnboardingAddAnotherPromptStep    — post-track "add another?" prompt.
//   • WizardChooseMethodStep            — "How do you review?" option cards.
@Tags(['onboarding', 'overflow'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_add_another_prompt_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_handoff_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/wizard_steps.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';

import '../../../../helpers/overflow_harness.dart';

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

OnboardingStepContext _ctx() => OnboardingStepContext(
  advance: () async {},
  retreat: () {},
  stepIndex: 0,
  totalSteps: 3,
);

LearningProgramData _preset(int id) => LearningProgramData(
  id: id,
  name: 'Program $id',
  displayName: 'Program $id',
  description: 'A test program with a reasonably long description line',
  curriculumType: 'mishnayos',
  isActive: true,
  hasTests: false,
  stagesConfig: '[]',
  testConfig: '{}',
  apiSource: null,
  apiProgramKey: null,
  isCalendarProgram: false,
);

void main() {
  testWidgets('OnboardingHandoffStep does not overflow across devices', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      () => const OnboardingHandoffStep(
        profileName: 'Yael',
        onStartLearning: _noop,
        onAddAnotherTrack: _noop,
        onAddAnotherLearner: _noop,
      ),
    );
  });

  testWidgets(
    'OnboardingAddAnotherPromptStep does not overflow across devices',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const OnboardingAddAnotherPromptStep(
          trackCount: 2,
          lastTrackLabel: 'Mishnayos — Berakhos',
          onStartLearning: _noop,
          onAddAnotherTrack: _noop,
        ),
      );
    },
  );

  testWidgets('WizardChooseMethodStep does not overflow across devices', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      () => Consumer(
        builder: (context, ref, _) => WizardChooseMethodStep(
          curriculumId: CurriculumId.mishnayos,
          presets: [_preset(1), _preset(2)],
          isChildMode: true,
          childName: 'Yael',
          onComplete: (_) {},
        ).build(context, ref, _ctx()),
      ),
      overrides: [
        useHebrewTermsProvider.overrideWith(_FalseUseHebrewTerms.new),
      ],
    );
  });
}

void _noop() {}
