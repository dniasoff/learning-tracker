// Multi-device overflow guard.
//
// Proves the [expectNoOverflowAcrossDevices] harness:
//   1. PASSES on a well-built, scroll-safe confirm-dialog ("Exit Track Setup?"
//      shape) across the whole device/text-scale matrix.
//   2. PASSES on a scroll-wrapped tall Column even at small×2.0.
//   3. PASSES on the SHARED overflow-safe dialog (`showAppConfirmDialog` from
//      `lib/core/widgets/app_dialog.dart`) with a very long title + message at
//      the worst corner of the matrix.
//   4. PASSES on the real [StartingPositionCalendarMode] screen (the widget
//      that shipped the original "BOTTOM OVERFLOWED BY 59 PIXELS" regression,
//      see AUD-t-cross-34) across the whole device/text-scale matrix.
//   5. FAILS (self-test) on a deliberately-overflowing fixed Column at the
//      small viewport × 2.0 text — demonstrating the guard actually catches
//      real "RenderFlex overflowed by N pixels" regressions.
//
// HOW TO EXTEND: add a `testWidgets` here for every dialog/screen you want
// guarded — `await expectNoOverflowAcrossDevices(tester, () => YourWidget(),
// overrides: [...])`.

@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/overflow_harness.dart';

// ── StartingPositionCalendarMode fixtures ───────────────────────────────────

class _MockCalendarProgramService extends Mock
    implements CalendarProgramService {}

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

LearningProgramData _dafYomiProgram() => const LearningProgramData(
  id: 1,
  name: 'Daf Yomi',
  displayName: 'Daf Yomi',
  description: 'Test program',
  curriculumType: 'bavli',
  isActive: true,
  hasTests: false,
  stagesConfig: '',
  testConfig: '',
  apiSource: 'local',
  apiProgramKey: 'daf_yomi',
  isCalendarProgram: true,
);

/// A confirm-dialog content widget shaped like "Exit Track Setup?":
/// a title, a long body message, and two action buttons in a Column.
///
/// This is the GOOD version: the message column is wrapped so that on a tiny
/// screen with huge text it scrolls instead of overflowing. This is the
/// pattern every real confirm dialog in the app should follow.
class _SafeConfirmDialogContent extends StatelessWidget {
  const _SafeConfirmDialogContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Exit Track Setup?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                // The long body is the part most likely to overflow under
                // large text — keep it inside a Flexible+scroll so it can't.
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      'Your progress on this track will not be saved if you '
                      'leave now. You can come back and finish setting up the '
                      'track at any time from the tracks screen. Are you sure '
                      'you want to exit the setup flow?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    FilledButton(onPressed: () {}, child: const Text('Exit')),
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

/// The BAD version: same shape, but a fixed (non-scrolling) Column of
/// generously-sized fixed-height blocks. On a 320×568 viewport with 2.0×
/// text this is forced taller than the screen → RenderFlex overflow.
///
/// Used by the self-test to prove the guard catches real overflows.
class _OverflowingFixedColumn extends StatelessWidget {
  const _OverflowingFixedColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 12; i++)
          Container(
            height: 80,
            margin: const EdgeInsets.all(6),
            color: Colors.blue.shade100,
            alignment: Alignment.center,
            child: Text(
              'Row $i — a long line of text that grows with the scale factor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
    );
  }
}

/// Scroll-wrapped version of the same tall content — must NOT overflow.
class _ScrollableTallColumn extends StatelessWidget {
  const _ScrollableTallColumn();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(child: _OverflowingFixedColumn());
  }
}

/// Host that auto-opens the SHARED [showAppConfirmDialog] once it's mounted.
///
/// The dialog is the production "Exit Track Setup?" primitive. We feed it an
/// intentionally enormous title + message so that, absent the shell's built-in
/// scroll/height-clamp, it WOULD overflow the smallest viewport at 2.0× text.
/// Because the shell wraps its body in a height-clamped SingleChildScrollView,
/// it must stay overflow-free across the whole matrix.
class _AppDialogHost extends StatefulWidget {
  const _AppDialogHost();

  @override
  State<_AppDialogHost> createState() => _AppDialogHostState();
}

class _AppDialogHostState extends State<_AppDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppConfirmDialog(
        context: context,
        title: 'Exit Track Setup? You will lose all of your unsaved progress',
        message:
            'Your progress on this track will not be saved if you leave now. '
            'You can come back and finish setting up the track at any time '
            'from the tracks screen. This message is deliberately long so the '
            'dialog body is taller than a 320x568 viewport at 2.0x text, which '
            'proves the shared dialog shell scrolls instead of overflowing. '
            'Are you absolutely sure you want to exit the setup flow right now?',
        confirmLabel: 'Exit',
        cancelLabel: 'Cancel',
        destructive: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  // ── PASSING real-surface cases ──────────────────────────────────────────

  testWidgets(
    'confirm-dialog ("Exit Track Setup?" shape) does not overflow across the '
    'device matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _SafeConfirmDialogContent(),
      );
    },
  );

  testWidgets(
    'scroll-wrapped tall column does not overflow (incl. small×2.0)',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const _ScrollableTallColumn(),
      );
    },
  );

  testWidgets(
    'shared showAppConfirmDialog (long title+message) does not overflow across '
    'the device matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(tester, () => const _AppDialogHost());
    },
  );

  testWidgets(
    'StartingPositionCalendarMode (AUD-t-cross-34) does not overflow across '
    'the device matrix',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await expectNoOverflowAcrossDevices(
        tester,
        () => StartingPositionCalendarMode(
          selectedProgram: _dafYomiProgram(),
          onComplete: (_) {},
        ),
        overrides: [
          calendarProgramServiceProvider.overrideWith(
            (ref) => Future.value(calendarSvc),
          ),
          useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
        ],
      );
    },
  );

  // ── SELF-TEST: the guard MUST fail on a real overflow ───────────────────
  //
  // We invert the assertion: we EXPECT expectNoOverflowAcrossDevices to throw
  // a TestFailure when handed a layout that genuinely overflows at small×2.0.
  // If it ever passes, the guard is broken and this test fails loudly.

  testWidgets(
    'SELF-TEST: guard catches a deliberately-overflowing fixed Column',
    (tester) async {
      Object? caught;
      try {
        await expectNoOverflowAcrossDevices(
          tester,
          () => const _OverflowingFixedColumn(),
        );
      } catch (e) {
        caught = e;
      }

      expect(
        caught,
        isA<TestFailure>(),
        reason:
            'The overflow guard must fail on a fixed Column that overflows the '
            '320×568 viewport at 2.0× text. If this assertion fails, the guard '
            'is no longer catching real RenderFlex overflows.',
      );
      expect(
        caught.toString(),
        contains('Layout overflowed'),
        reason: 'Failure message must name the overflow so the corner is clear',
      );
    },
  );

  // ── Self-tests of the matrix builder (cheap, no pumping) ─────────────────

  test('default matrix covers the required extremes', () {
    final matrix = defaultOverflowMatrix();
    final labels = matrix.map((c) => c.label).toSet();

    // small×1.0, small×2.0 and tablet×1.0 are contractually required.
    expect(labels, contains('320x568 @ 1.0x text (dpr 1.0)'));
    expect(labels, contains('320x568 @ 2.0x text (dpr 1.0)'));
    expect(labels, contains('768x1024 @ 1.0x text (dpr 1.0)'));
    // tall-narrow foldable at max scale (worst width corner).
    expect(labels, contains('280x653 @ 2.0x text (dpr 1.0)'));
    // De-duplicated and bounded so the suite stays fast.
    expect(matrix.length, lessThanOrEqualTo(10));
    expect(matrix.length, labels.length); // no duplicate cases.
  });
}
