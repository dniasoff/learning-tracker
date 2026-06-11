/// Regression test for TS-11:
/// The Add-Track wizard shows "STEP 1 OF N" on the curriculum step. When the
/// previously-selected curriculum has active programs, the program step would be
/// included, showing "STEP 1 OF 7" before the user has chosen whether to use a
/// program. The denominator must show the minimum (program-free) path on step 1.
///
/// Fix: expose [computeWizardStepTotal] — a pure function that returns the
/// display total, excluding the program step on the curriculum step (index 0).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';

void main() {
  group('TS-11 — wizard step total denominator stability', () {
    test('on curriculum step (index 0) denominator excludes program step', () {
      // curriculumHasPrograms=true, programConfirmed=false → must show 6 not 7
      final total = computeWizardStepTotal(
        currentIndex: 0,
        fullStepCount: 7, // includes program step
        hasProgramStep: true,
        programConfirmed: false,
      );
      expect(
        total,
        equals(6),
        reason:
            'TS-11: curriculum step denominator must not include program step '
            'before the user has confirmed a program selection',
      );
    });

    test('on program step (index 1) denominator includes program step', () {
      final total = computeWizardStepTotal(
        currentIndex: 1,
        fullStepCount: 7,
        hasProgramStep: true,
        programConfirmed: false,
      );
      expect(
        total,
        equals(7),
        reason:
            'Once on the program step, show full count including program step',
      );
    });

    test(
      'on curriculum step when no programs available denominator unchanged',
      () {
        // 6-step self-paced track (no program step)
        final total = computeWizardStepTotal(
          currentIndex: 0,
          fullStepCount: 6,
          hasProgramStep: false,
          programConfirmed: false,
        );
        expect(total, equals(6));
      },
    );

    test(
      'on curriculum step when program already confirmed denominator unchanged',
      () {
        // User backed up to step 1 with programId still set
        final total = computeWizardStepTotal(
          currentIndex: 0,
          fullStepCount: 7,
          hasProgramStep: true,
          programConfirmed: true,
        );
        // Denominator should still show the correct count since program is confirmed
        expect(total, equals(7));
      },
    );
  });
}
