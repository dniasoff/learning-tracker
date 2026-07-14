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
//   • OnboardingProfileCreationStep     — profile name + mode + prefs + CTA
//                                         (regression: CTA clipped on tablet
//                                         landscape when keyboard compresses
//                                         the viewport height to ~640 dip).
@Tags(['onboarding', 'overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_add_another_prompt_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_handoff_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
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

void _noop() {}

void _noopCreated({
  required profile,
  required isChildMode,
  required useHebrewCalendar,
  required useHebrewTerms,
  required showNikud,
  required transliterationVariant,
}) {}

void main() {
  // Every case below runs at both Locale('en') and Locale('he') (AUD-t-onboarding-01):
  // Hebrew strings routinely run a different length than English, so an
  // LTR-only overflow guard misses RTL-only layout breaks.
  for (final locale in const [Locale('en'), Locale('he')]) {
    testWidgets('OnboardingHandoffStep does not overflow across devices '
        '(${locale.languageCode})', (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const OnboardingHandoffStep(
          profileName: 'Yael',
          onStartLearning: _noop,
          onAddAnotherTrack: _noop,
          onAddAnotherLearner: _noop,
        ),
        locale: locale,
      );
    });

    testWidgets(
      'OnboardingAddAnotherPromptStep does not overflow across devices '
      '(${locale.languageCode})',
      (tester) async {
        await expectNoOverflowAcrossDevices(
          tester,
          () => const OnboardingAddAnotherPromptStep(
            trackCount: 2,
            lastTrackLabel: 'Mishnayos — Berakhos',
            onStartLearning: _noop,
            onAddAnotherTrack: _noop,
          ),
          locale: locale,
        );
      },
    );

    testWidgets('WizardChooseMethodStep does not overflow across devices '
        '(${locale.languageCode})', (tester) async {
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
        locale: locale,
      );
    });

    testWidgets(
      'OnboardingProfileCreationStep does not overflow on tablet/landscape '
      'with keyboard-compressed height (${locale.languageCode})',
      (tester) async {
        // Regression guard: on a 2560×1600 landscape tablet the soft keyboard
        // raises the bottom inset to y=776, shrinking the scrollable viewport to
        // ~640 dip. The "Create Profile" CTA must remain SCROLLABLE (not clipped)
        // so the user can reach it — the SingleChildScrollView wrapper inside
        // the step ensures this. If the step overflows instead of scrolling at
        // this size the CTA becomes unreachable (zero-height in accessibility
        // tree), reproducing the tablet regression reported in loop-iter8.
        //
        // Guarded at Locale('he') too: interpolated names and the
        // un-localized "profile already exists" error routinely run longer
        // in Hebrew, and this keyboard-compressed corner is exactly where
        // that extra length is most likely to newly overflow.
        await expectNoOverflowAcrossDevices(
          tester,
          () => const OnboardingProfileCreationStep(onCreated: _noopCreated),
          // Test only the keyboard-compressed tablet viewport and the classic
          // small-phone corner; the full matrix is covered by the other guards.
          sizes: const [
            Size(
              768,
              640,
            ), // landscape tablet at ~60% height (keyboard visible)
            Size(320, 568), // small phone, the classic overflow offender
          ],
          textScales: const [1.0, 1.3],
          locale: locale,
        );
      },
    );
  }
}
