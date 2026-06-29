/// Regression test for TS-11 (run-7 refinement):
/// The Add-Track wizard shows "STEP n OF N". When a curriculum with active
/// programs is chosen, the program step is added — which previously made the
/// denominator jump from 6 to 7 *across the slide* from the curriculum step to
/// the program step ("STEP 1 OF 6" → "STEP 2 OF 7").
///
/// Fix: [computeWizardStepTotal] keeps the denominator STABLE. The program step
/// is excluded only while NO curriculum has been selected yet. The instant a
/// curriculum is picked (even while still on the curriculum step, index 0) the
/// full count is shown, so the total never changes on the slide to step 1.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';

void main() {
  group('TS-11 — wizard step total denominator stability', () {
    test(
      'curriculum step, nothing selected yet → excludes program step (6)',
      () {
        // Fresh wizard, no curriculum tapped: show the minimum program-free
        // path so the total is not inflated before any choice is made.
        final total = computeWizardStepTotal(
          currentIndex: 0,
          fullStepCount: 7, // includes program step
          hasProgramStep: true,
          curriculumSelected: false,
        );
        expect(
          total,
          equals(6),
          reason:
              'Before any curriculum is chosen the program step must be '
              'excluded from the denominator',
        );
      },
    );

    test(
      'curriculum step, curriculum just selected → shows full count (7)',
      () {
        // The moment a program-bearing curriculum is tapped, the final step
        // count is known. Showing 7 here (still on index 0) means the total
        // does NOT jump when the page slides to the program step.
        final total = computeWizardStepTotal(
          currentIndex: 0,
          fullStepCount: 7,
          hasProgramStep: true,
          curriculumSelected: true,
        );
        expect(
          total,
          equals(7),
          reason:
              'Once a curriculum is selected the denominator is stable at the '
              'full count, preventing a 6→7 jump on the slide to step 1',
        );
      },
    );

    test('program step (index 1) → shows full count (7)', () {
      final total = computeWizardStepTotal(
        currentIndex: 1,
        fullStepCount: 7,
        hasProgramStep: true,
        curriculumSelected: true,
      );
      expect(total, equals(7));
    });

    test('curriculum with no programs → denominator unchanged (6)', () {
      // Self-paced-only curriculum: no program step exists, so the count is
      // already the full path regardless of selection state.
      final total = computeWizardStepTotal(
        currentIndex: 0,
        fullStepCount: 6,
        hasProgramStep: false,
        curriculumSelected: false,
      );
      expect(total, equals(6));
    });
  });
}
