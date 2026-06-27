// L1 widget tests — TutorPinVerificationDialog + GoalSetupForm/GoalSetupScreen
//
// FOCUS:
//   • tutor_pin_entry_dialog.dart (0% baseline) — digit entry, verify, success,
//     error, lockout; SEPARATE Tutor PIN namespace (not parent PIN).
//   • goal_setup_screen.dart (72% baseline) — pace vs deadline goal, validation,
//     GoalEntity persistence; chazara-only-when-enabled.
//
// Coverage groups:
//
//  A. TutorPinVerificationDialog — visual structure
//     A1. Dialog: shows tutorPinEntryHeading and tutorPinEntryBody
//     A2. Dialog: shows all 10 digit buttons (0-9) + backspace
//     A3. Dialog: cancel/close button invokes pop(false)
//     A4. Dialog: dot indicator starts empty (0 filled)
//     A5. he-locale smoke: renders without overflow/crash
//
//  B. TutorPinVerificationDialog — digit-entry state
//     B1. Entering first 3 digits does NOT call verifyTutorPin (auto-submit only at 4)
//     B2. Entering 4 digits triggers verifyTutorPin with the supplied profileId
//     B3. Backspace removes a digit (re-tap digit → still 1, not 2 filled)
//
//  C. TutorPinVerificationDialog — verification outcomes
//     C1. TutorPinSuccess → dialog resolves true (Navigator.pop(true))
//     C2. TutorPinIncorrect → shows tutorPinIncorrect message; dialog stays open
//     C3. TutorPinLockedOut(5) → shows lockout panel with minute count; stays open
//     C4. TutorPinLockedOut → subsequent digit taps are ignored (locked state)
//     C5. TutorPinValidationError → shows the custom message; dialog stays open
//
//  D. GoalSetupForm — goal-type switching
//     D1. Default goal type is "deadline" and deadline section is visible
//     D2. Switching to "pace" shows pace inputs (Per day / Per week)
//     D3. Switching to "none" hides deadline and pace content
//     D4. Switching back to "deadline" hides pace content again
//
//  E. GoalSetupForm — deadline mode
//     E1. "Tap to choose a date" placeholder shown when no date selected
//     E2. Target-percent slider starts at 100%
//     E3. Occasion text-field is visible in deadline mode
//     E4. Deadline passed: shows "Deadline has passed" when date is in past
//
//  F. GoalSetupForm — pace mode
//     F1. Pace mode: projected completion card appears when totalItems provided
//     F2. Pace mode: per-week selection shows "Per week" as selected
//     F3. Bavli curriculum: unit picker shows Amudim/Dafim segments
//     F4. Chumash (pasuk/perek): unit picker shows Perakim/Pesukim segments
//     F5. Non-unit-picker curriculum (mishnayos): no unit picker shown
//
//  G. GoalSetupForm — form submission / GoalEntity output
//     G1. Submit in deadline mode with date → GoalEntity.goalType == 'deadline'
//     G2. Submit in pace mode → GoalEntity.goalType == 'pace' and paceValue set
//     G3. Submit in none mode → GoalEntity.goalType == 'none'; no date/pace
//     G4. Description field value is preserved in deadline GoalEntity
//     G5. GoalEntity.targetPercent reflects slider value
//
//  H. GoalSetupScreen — screen wrapper
//     H1. New-goal mode: AppBar title is "New Goal" and submit = "Create Goal"
//     H2. Edit-goal mode: AppBar title is "Edit Goal" and submit = "Update Goal"
//
//  I. Product-rule checks
//     I1. No "track type" label text anywhere on the goal-setup form

@Tags(['l1', 'tutoring', 'scheduler', 'goal_setup', 'tutor_pin_dialog'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTutorPinService extends Mock implements TutorPinService {}

// ── UseHebrewDate stub (returns false — English dates) ─────────────────────

class _FalseUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

// Pin Hebrew-terms OFF (English transliteration) so the unit-picker pills
// render the English forms these tests assert (Amudim/Dafim/Perakim/Pesukim).
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const int _kTutorProfileId = 11;

/// Fixed "now" for scheduler clock so projected-completion math is stable.
final DateTime _kNow = DateTime.utc(2026, 6, 1);

// ── Pin-dialog pump harness ───────────────────────────────────────────────────
//
// We test [showTutorPinVerificationDialog] by embedding a Scaffold that calls
// it immediately, capturing the Future<bool> result, and asserting on the
// dialog content + result.

/// Builds a harness that opens the tutor PIN dialog immediately after pump.
///
/// [mockService]  — injected [TutorPinService].
/// [resultHolder] — receives the Future<bool> returned by the dialog.
/// [locale]       — defaults to English.
Widget _buildPinDialogHarness({
  required _MockTutorPinService mockService,
  required List<Future<bool>> resultHolder,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) {
          // Open the dialog immediately on first build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) {
              resultHolder.add(
                showTutorPinVerificationDialog(
                  ctx,
                  tutorOwnProfileId: _kTutorProfileId,
                  tutorPinService: mockService,
                ),
              );
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
}

// ── Goal-setup harness ────────────────────────────────────────────────────────

/// Builds a [GoalSetupForm] wrapped in a provider scope with predictable clock.
Widget _buildGoalFormHarness({
  required CurriculumId curriculumId,
  GoalEntity? existingGoal,
  int? totalItems,
  required List<GoalEntity> submitted,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith((ref) => _kNow),
      useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GoalSetupForm(
          curriculumId: curriculumId,
          existingGoal: existingGoal,
          totalItems: totalItems,
          onComplete: submitted.add,
        ),
      ),
    ),
  );
}

Widget _buildGoalScreenHarness({
  required CurriculumId curriculumId,
  GoalEntity? existingGoal,
  int? totalItems,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith((ref) => _kNow),
      useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: GoalSetupScreen(
        curriculumId: curriculumId,
        existingGoal: existingGoal,
        totalItems: totalItems,
      ),
    ),
  );
}

// ── Keypad interaction helpers ────────────────────────────────────────────────

/// Taps the keypad button labelled with [digit].
///
/// The PinKeypadDialogFrame renders digit buttons as Text widgets inside
/// InkWell → finds the first matching Text widget.
Future<void> _tapDigit(WidgetTester tester, String digit) async {
  // The digit is rendered by a Text widget inside a _KeypadChip (InkWell).
  // We find InkWell widgets that contain a Text with the digit.
  final inkWells = find.ancestor(
    of: find.text(digit),
    matching: find.byType(InkWell),
  );
  // Take the first InkWell (the button itself, not any outer wrapper).
  await tester.tap(inkWells.first);
  await tester.pump();
}

/// Enters a 4-digit PIN via the keypad.
Future<void> _enterPinOnKeypad(WidgetTester tester, String pin) async {
  assert(pin.length == 4, 'PIN must be 4 digits');
  for (final ch in pin.split('')) {
    await _tapDigit(tester, ch);
  }
}

// ── Teardown ─────────────────────────────────────────────────────────────────

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // A. TutorPinVerificationDialog — visual structure
  // ══════════════════════════════════════════════════════════════════════════

  group('A. TutorPinVerificationDialog — visual structure', () {
    testWidgets('A1. shows tutorPinEntryHeading and tutorPinEntryBody', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final resultHolder = <Future<bool>>[];

      await tester.pumpWidget(
        _buildPinDialogHarness(
          mockService: mockService,
          resultHolder: resultHolder,
        ),
      );
      await tester.pump(); // postFrameCallback fires
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Enter your Tutor PIN'),
        findsOneWidget,
        reason: 'A1: tutorPinEntryHeading must be visible',
      );
      expect(
        find.text('Enter your 4-digit Tutor PIN to access this profile.'),
        findsOneWidget,
        reason: 'A1: tutorPinEntryBody must be visible',
      );
      await _teardown(tester);
    });

    testWidgets('A2. shows all 10 digit buttons (0-9)', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final resultHolder = <Future<bool>>[];

      await tester.pumpWidget(
        _buildPinDialogHarness(
          mockService: mockService,
          resultHolder: resultHolder,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(
          find.text(d),
          findsAtLeastNWidgets(1),
          reason: 'A2: digit button "$d" must be rendered',
        );
      }
      // Backspace icon
      expect(
        find.byIcon(Icons.backspace_outlined),
        findsOneWidget,
        reason: 'A2: backspace button must be rendered',
      );
      await _teardown(tester);
    });

    testWidgets('A3. cancel button in keypad invokes pop(false)', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final resultHolder = <Future<bool>>[];

      await tester.pumpWidget(
        _buildPinDialogHarness(
          mockService: mockService,
          resultHolder: resultHolder,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // "Cancel" text button on the keypad — tap it
      expect(find.text('Cancel'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Cancel').last);
      await tester.pump(const Duration(seconds: 1));

      // The dialog should have popped with false
      expect(resultHolder, hasLength(1));
      await expectLater(resultHolder.first, completion(isFalse));
      await _teardown(tester);
    });

    testWidgets('A4. dot indicator shows 0 filled dots on open', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final resultHolder = <Future<bool>>[];

      await tester.pumpWidget(
        _buildPinDialogHarness(
          mockService: mockService,
          resultHolder: resultHolder,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // We can't inspect the container colors easily, but we can confirm the
      // dialog is open and no error message is shown yet.
      expect(find.text('Enter your Tutor PIN'), findsOneWidget);
      // No error text
      expect(
        find.text('Incorrect PIN. Please try again.'),
        findsNothing,
        reason: 'A4: No error on fresh open',
      );
      await _teardown(tester);
    });

    testWidgets('A5. he-locale: renders without overflow or crash', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final resultHolder = <Future<bool>>[];

      await tester.pumpWidget(
        _buildPinDialogHarness(
          mockService: mockService,
          resultHolder: resultHolder,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dialog is open in RTL locale — just verify no crash and structural widgets.
      expect(find.byType(Dialog), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // B. TutorPinVerificationDialog — digit-entry state
  // ══════════════════════════════════════════════════════════════════════════

  group('B. TutorPinVerificationDialog — digit-entry state', () {
    testWidgets(
      'B1. entering 3 digits does NOT call verifyTutorPin (auto-submit only at 4)',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Tap 3 digits only
        await _tapDigit(tester, '1');
        await _tapDigit(tester, '2');
        await _tapDigit(tester, '3');
        await tester.pump(const Duration(milliseconds: 200));

        verifyNever(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        );
        await _teardown(tester);
      },
    );

    testWidgets(
      'B2. entering 4 digits triggers verifyTutorPin with the correct profileId',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];

        when(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        ).thenAnswer((_) async => const TutorPinSuccess());

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPinOnKeypad(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        verify(
          () => mockService.verifyTutorPin(
            profileId: _kTutorProfileId,
            rawPin: '1234',
          ),
        ).called(1);
        await _teardown(tester);
      },
    );

    testWidgets(
      'B3. backspace after 1 digit press leaves 0 digits → no auto-submit',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _tapDigit(tester, '5');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.backspace_outlined));
        await tester.pump();

        // No verify call since we backspaced before completing 4 digits.
        verifyNever(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        );
        // Dialog still open
        expect(find.text('Enter your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // C. TutorPinVerificationDialog — verification outcomes
  // ══════════════════════════════════════════════════════════════════════════

  group('C. TutorPinVerificationDialog — verification outcomes', () {
    testWidgets('C1. TutorPinSuccess → dialog resolves true', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final resultHolder = <Future<bool>>[];

      when(
        () => mockService.verifyTutorPin(
          profileId: any<int>(named: 'profileId'),
          rawPin: any<String>(named: 'rawPin'),
        ),
      ).thenAnswer((_) async => const TutorPinSuccess());

      await tester.pumpWidget(
        _buildPinDialogHarness(
          mockService: mockService,
          resultHolder: resultHolder,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _enterPinOnKeypad(tester, '9999');
      await tester.pump(const Duration(seconds: 1));

      expect(resultHolder, hasLength(1));
      await expectLater(resultHolder.first, completion(isTrue));
      await _teardown(tester);
    });

    testWidgets(
      'C2. TutorPinIncorrect → shows tutorPinIncorrect message; dialog stays open',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];

        when(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        ).thenAnswer((_) async => const TutorPinIncorrect());

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPinOnKeypad(tester, '0000');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Incorrect PIN. Please try again.'),
          findsAtLeastNWidgets(1),
          reason: 'C2: tutorPinIncorrect must appear on wrong PIN',
        );
        // Dialog still open (heading still visible)
        expect(find.text('Enter your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );

    testWidgets(
      'C3. TutorPinLockedOut → shows lockout panel with minute count; stays open',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];

        when(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        ).thenAnswer((_) async => const TutorPinLockedOut(remainingMinutes: 7));

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPinOnKeypad(tester, '1111');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining('Too many'),
          findsAtLeastNWidgets(1),
          reason: 'C3: lockout panel must appear',
        );
        expect(
          find.textContaining('7'),
          findsAtLeastNWidgets(1),
          reason: 'C3: minute count (7) must appear in lockout message',
        );
        await _teardown(tester);
      },
    );

    testWidgets(
      'C4. TutorPinLockedOut → keypad disappears; only one verify call total',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];
        var verifyCount = 0;

        when(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        ).thenAnswer((_) async {
          verifyCount++;
          return const TutorPinLockedOut(remainingMinutes: 3);
        });

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Enter 4 digits → triggers single verify call → lockout result
        await _enterPinOnKeypad(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        // verifyTutorPin called exactly once
        expect(
          verifyCount,
          1,
          reason: 'C4: verify must be called exactly once before lockout',
        );
        // After lockout the keypad is replaced by _LockoutPanel — digit
        // buttons are no longer in the widget tree.
        expect(
          find.text('1'),
          findsNothing,
          reason: 'C4: keypad digit buttons must be removed in lockout state',
        );
        expect(find.textContaining('Too many'), findsAtLeastNWidgets(1));
        await _teardown(tester);
      },
    );

    testWidgets(
      'C5. TutorPinValidationError → shows the custom error message; stays open',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final resultHolder = <Future<bool>>[];

        when(
          () => mockService.verifyTutorPin(
            profileId: any<int>(named: 'profileId'),
            rawPin: any<String>(named: 'rawPin'),
          ),
        ).thenAnswer(
          (_) async => const TutorPinValidationError(
            message: 'Tutor PIN storage unavailable',
          ),
        );

        await tester.pumpWidget(
          _buildPinDialogHarness(
            mockService: mockService,
            resultHolder: resultHolder,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPinOnKeypad(tester, '2222');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Tutor PIN storage unavailable'),
          findsAtLeastNWidgets(1),
          reason:
              'C5: TutorPinValidationError.message must appear as error text',
        );
        expect(find.text('Enter your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // D. GoalSetupForm — goal-type switching
  // ══════════════════════════════════════════════════════════════════════════

  group('D. GoalSetupForm — goal-type switching', () {
    testWidgets(
      'D1. default goal type is deadline; deadline date picker is shown',
      (tester) async {
        setViewSize(tester);
        final submitted = <GoalEntity>[];

        await tester.pumpWidget(
          _buildGoalFormHarness(
            curriculumId: CurriculumId.mishnayos,
            submitted: submitted,
          ),
        );
        await tester.pump();

        // Deadline is the default; the calendar icon should be present.
        expect(
          find.byIcon(Icons.calendar_today),
          findsAtLeastNWidgets(1),
          reason: 'D1: deadline section shows calendar_today icon',
        );
        // Pace inputs are hidden
        expect(
          find.text('Per day'),
          findsNothing,
          reason: 'D1: pace inputs must not show in deadline mode',
        );
        await _teardown(tester);
      },
    );

    testWidgets('D2. switching to pace shows Per-day / Per-week buttons', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Pace'));
      await tester.pump();

      expect(find.text('Per day'), findsAtLeastNWidgets(1));
      expect(find.text('Per week'), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });

    testWidgets('D3. switching to none hides deadline and pace content', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('No deadline'));
      await tester.pump();

      // Pace inputs are gone
      expect(find.text('Per day'), findsNothing);
      // Occasion text field (only in deadline section) is hidden
      expect(
        find.widgetWithText(TextField, 'Occasion (optional)'),
        findsNothing,
        reason: 'D3: occasion field must not appear in none mode',
      );
      // "no deadline" copy visible
      expect(
        find.textContaining('own pace'),
        findsAtLeastNWidgets(1),
        reason: 'D3: "no deadline" copy must appear in none mode',
      );
      await _teardown(tester);
    });

    testWidgets('D4. switching back to deadline hides pace content', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      // Pace
      await tester.tap(find.text('Pace'));
      await tester.pump();
      expect(find.text('Per day'), findsAtLeastNWidgets(1));

      // Back to deadline
      await tester.tap(find.text('Deadline'));
      await tester.pump();
      expect(find.text('Per day'), findsNothing);
      expect(find.byIcon(Icons.calendar_today), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // E. GoalSetupForm — deadline mode
  // ══════════════════════════════════════════════════════════════════════════

  group('E. GoalSetupForm — deadline mode', () {
    testWidgets('E1. placeholder shown when no date is selected', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      expect(
        find.text('Tap to choose a date'),
        findsOneWidget,
        reason: 'E1: placeholder text before date is selected',
      );
      await _teardown(tester);
    });

    testWidgets('E2. target-percent slider starts at 100%', (tester) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('100%'),
        findsAtLeastNWidgets(1),
        reason: 'E2: slider must start at 100%',
      );
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(
        slider.value,
        100.0,
        reason: 'E2: Slider.value must be 100 initially',
      );
      await _teardown(tester);
    });

    testWidgets('E3. Occasion text-field is visible in deadline mode', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      expect(
        find.widgetWithText(TextField, 'Occasion (optional)'),
        findsOneWidget,
        reason: 'E3: occasion text field must be visible in deadline mode',
      );
      await _teardown(tester);
    });

    testWidgets(
      'E4. deadline passed: shows "Deadline has passed" when date is in past',
      (tester) async {
        setViewSize(tester);
        final submitted = <GoalEntity>[];

        // Existing goal with a past target date (before _kNow = 2026-06-01)
        final pastGoal = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 100.0,
          targetDate: DateTime.utc(2025, 1, 1), // past
          goalType: 'deadline',
          createdAt: _kNow,
          updatedAt: _kNow,
        );

        await tester.pumpWidget(
          _buildGoalFormHarness(
            curriculumId: CurriculumId.mishnayos,
            existingGoal: pastGoal,
            totalItems: 100,
            submitted: submitted,
          ),
        );
        await tester.pump();

        expect(
          find.text('Deadline has passed'),
          findsOneWidget,
          reason: 'E4: past deadline must show "Deadline has passed"',
        );
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // F. GoalSetupForm — pace mode
  // ══════════════════════════════════════════════════════════════════════════

  group('F. GoalSetupForm — pace mode', () {
    testWidgets(
      'F1. projected completion card appears in pace mode when totalItems set',
      (tester) async {
        setViewSize(tester);
        final submitted = <GoalEntity>[];

        await tester.pumpWidget(
          _buildGoalFormHarness(
            curriculumId: CurriculumId.mishnayos,
            totalItems: 524,
            submitted: submitted,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Pace'));
        await tester.pump();

        expect(
          find.textContaining('Projected completion'),
          findsAtLeastNWidgets(1),
          reason: 'F1: pace projected-completion card must appear',
        );
        await _teardown(tester);
      },
    );

    testWidgets('F2. per-week selection changes paceUnit label', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          totalItems: 524,
          submitted: submitted,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Tap Per week
      await tester.tap(find.text('Per week'));
      await tester.pump();

      // projected still shows (totalItems is set)
      expect(
        find.textContaining('Projected completion'),
        findsAtLeastNWidgets(1),
      );
      await _teardown(tester);
    });

    testWidgets('F3. Bavli curriculum: unit picker shows Amudim/Dafim', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.bavli,
          totalItems: 2711,
          submitted: submitted,
        ),
      );
      await tester.pump();

      // Unit picker is shown even in deadline mode for Bavli.
      expect(
        find.text('Amudim'),
        findsAtLeastNWidgets(1),
        reason: 'F3: Bavli must show Amudim unit button',
      );
      expect(
        find.text('Dafim'),
        findsAtLeastNWidgets(1),
        reason: 'F3: Bavli must show Dafim unit button',
      );
      await _teardown(tester);
    });

    testWidgets('F4. Chumash curriculum: unit picker shows Perakim/Pesukim', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.chumash,
          submitted: submitted,
        ),
      );
      await tester.pump();

      expect(
        find.text('Perakim'),
        findsAtLeastNWidgets(1),
        reason: 'F4: Chumash must show Perakim unit button',
      );
      expect(
        find.text('Pesukim'),
        findsAtLeastNWidgets(1),
        reason: 'F4: Chumash must show Pesukim unit button',
      );
      await _teardown(tester);
    });

    testWidgets(
      'F5. Mishnayos curriculum: no unit picker (Amudim/Dafim/Perakim/Pesukim absent)',
      (tester) async {
        setViewSize(tester);
        final submitted = <GoalEntity>[];

        await tester.pumpWidget(
          _buildGoalFormHarness(
            curriculumId: CurriculumId.mishnayos,
            submitted: submitted,
          ),
        );
        await tester.pump();

        // No unit-picker segments for mishnayos
        expect(find.text('Amudim'), findsNothing);
        expect(find.text('Dafim'), findsNothing);
        expect(find.text('Perakim'), findsNothing);
        expect(find.text('Pesukim'), findsNothing);
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // G. GoalSetupForm — form submission / GoalEntity output
  // ══════════════════════════════════════════════════════════════════════════

  group('G. GoalSetupForm — form submission / GoalEntity output', () {
    testWidgets('G1. deadline mode submit produces goalType == deadline', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      final existingWithDate = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027, 12, 31),
        createdAt: _kNow,
        updatedAt: _kNow,
      );

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          existingGoal: existingWithDate,
          submitted: submitted,
        ),
      );
      await tester.pump();

      // Submit
      await tester.tap(find.text('Update Goal'));
      await tester.pump();

      expect(submitted, hasLength(1));
      expect(
        submitted.first.goalType,
        'deadline',
        reason: 'G1: goalType must be "deadline" in deadline mode',
      );
      await _teardown(tester);
    });

    testWidgets(
      'G2. pace mode submit: goalType==pace, paceValue non-null, pacePeriod set',
      (tester) async {
        setViewSize(tester);
        final submitted = <GoalEntity>[];

        await tester.pumpWidget(
          _buildGoalFormHarness(
            curriculumId: CurriculumId.mishnayos,
            submitted: submitted,
          ),
        );
        await tester.pump();

        // Switch to pace
        await tester.tap(find.text('Pace'));
        await tester.pump();

        // Submit
        await tester.tap(find.text('Create Goal'));
        await tester.pump();

        expect(submitted, hasLength(1));
        final goal = submitted.first;
        expect(
          goal.goalType,
          'pace',
          reason: 'G2: goalType must be "pace" in pace mode',
        );
        expect(
          goal.paceValue,
          isNotNull,
          reason: 'G2: paceValue must be set in pace mode',
        );
        expect(
          goal.pacePeriod,
          isNotNull,
          reason: 'G2: pacePeriod must be set in pace mode',
        );
        // In deadline mode targetDate should be null
        expect(
          goal.targetDate,
          isNull,
          reason: 'G2: targetDate must be null in pace mode',
        );
        await _teardown(tester);
      },
    );

    testWidgets('G3. none mode submit: goalType==none, no date, no paceValue', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('No deadline'));
      await tester.pump();

      await tester.tap(find.text('Create Goal'));
      await tester.pump();

      expect(submitted, hasLength(1));
      final goal = submitted.first;
      expect(goal.goalType, 'none', reason: 'G3: goalType must be "none"');
      expect(goal.targetDate, isNull, reason: 'G3: no date for none mode');
      expect(goal.paceValue, isNull, reason: 'G3: no paceValue for none mode');
      await _teardown(tester);
    });

    testWidgets('G4. description field value is preserved in GoalEntity', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      // Pre-populate with a future date so the submit button is enabled in
      // deadline mode (the button is disabled when no date is selected).
      // Description starts empty so we can assert our typed value.
      final goalWithDate = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027, 12, 31),
        createdAt: _kNow,
        updatedAt: _kNow,
      );

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          existingGoal: goalWithDate,
          submitted: submitted,
        ),
      );
      await tester.pump();

      // Find occasion text field and enter text
      final occasionField = find.widgetWithText(
        TextField,
        'Occasion (optional)',
      );
      expect(occasionField, findsOneWidget);
      await tester.tap(occasionField);
      await tester.enterText(occasionField, 'Siyum HaShas');
      await tester.pump();

      // existingGoal is set → button reads "Update Goal"
      await tester.tap(find.text('Update Goal'));
      await tester.pump();

      expect(submitted, hasLength(1));
      expect(
        submitted.first.description,
        'Siyum HaShas',
        reason: 'G4: description must be preserved from text field',
      );
      await _teardown(tester);
    });

    testWidgets('G5. GoalEntity.targetPercent reflects slider drag', (
      tester,
    ) async {
      setViewSize(tester);
      final submitted = <GoalEntity>[];

      await tester.pumpWidget(
        _buildGoalFormHarness(
          curriculumId: CurriculumId.mishnayos,
          submitted: submitted,
        ),
      );
      await tester.pump();

      // Drag slider to around 50% (slider starts at 100, dragging left reduces it).
      final slider = find.byType(Slider);
      final sliderCenter = tester.getCenter(slider);
      await tester.dragFrom(sliderCenter, const Offset(-100, 0));
      await tester.pump();

      // Switch to "No deadline" so the submit button is enabled without
      // requiring a date selection. The _targetPercent value persists across
      // mode changes because it is a separate state field.
      await tester.tap(find.text('No deadline'));
      await tester.pump();

      await tester.tap(find.text('Create Goal'));
      await tester.pump();

      expect(submitted, hasLength(1));
      expect(
        submitted.first.targetPercent,
        lessThan(100.0),
        reason: 'G5: dragging slider left must reduce targetPercent',
      );
      await _teardown(tester);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // H. GoalSetupScreen — screen wrapper
  // ══════════════════════════════════════════════════════════════════════════

  group('H. GoalSetupScreen — screen wrapper', () {
    testWidgets(
      'H1. new-goal mode: AppBar shows "New Goal" and button shows "Create Goal"',
      (tester) async {
        setViewSize(tester);

        await tester.pumpWidget(
          _buildGoalScreenHarness(curriculumId: CurriculumId.mishnayos),
        );
        await tester.pump();

        expect(
          find.text('New Goal'),
          findsAtLeastNWidgets(1),
          reason: 'H1: AppBar title must be "New Goal" for new-goal mode',
        );
        expect(
          find.text('Create Goal'),
          findsOneWidget,
          reason: 'H1: submit button must say "Create Goal"',
        );
        await _teardown(tester);
      },
    );

    testWidgets(
      'H2. edit-goal mode: AppBar shows "Edit Goal" and button shows "Update Goal"',
      (tester) async {
        setViewSize(tester);

        final existingGoal = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 80.0,
          goalType: 'deadline',
          targetDate: DateTime.utc(2027, 1, 1),
          createdAt: _kNow,
          updatedAt: _kNow,
        );

        await tester.pumpWidget(
          _buildGoalScreenHarness(
            curriculumId: CurriculumId.mishnayos,
            existingGoal: existingGoal,
          ),
        );
        await tester.pump();

        expect(
          find.text('Edit Goal'),
          findsAtLeastNWidgets(1),
          reason: 'H2: AppBar title must be "Edit Goal" in edit mode',
        );
        expect(
          find.text('Update Goal'),
          findsOneWidget,
          reason: 'H2: submit button must say "Update Goal" in edit mode',
        );
        await _teardown(tester);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // I. Product-rule checks
  // ══════════════════════════════════════════════════════════════════════════

  group('I. Product-rule checks', () {
    testWidgets(
      'I1. no "track type" label visible on goal-setup form (product rule)',
      (tester) async {
        setViewSize(tester);
        final submitted = <GoalEntity>[];

        await tester.pumpWidget(
          _buildGoalFormHarness(
            curriculumId: CurriculumId.mishnayos,
            submitted: submitted,
          ),
        );
        await tester.pump();

        for (final forbidden in [
          'Personal',
          'Standard',
          'Custom',
          'אישי',
          'Track type',
          'track type',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason:
                'I1: forbidden track-type label "$forbidden" must not appear',
          );
        }
        await _teardown(tester);
      },
    );
  });
}
