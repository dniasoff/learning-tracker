// AUD-tracks-09 (SM-4 widget analog) regression guard for
// SelfPacedGoalStep._pickDeadline.
//
// Both branches of _pickDeadline call setState() immediately after an
// awaited date-picker dialog (HebrewDatePicker.show / showLearningAppDatePicker)
// with no `if (!mounted) return;` guard in between, unlike every other
// async-gap-then-setState call site in this batch. If the user backs out of
// the Add-Track wizard while the date picker is still open, the awaited
// Future resolves after State.dispose() and the resumed setState() throws
// (a framework error) instead of being a safe no-op.
//
// This test drives the real (non-Hebrew) date picker: it taps the inactive
// deadline card to open showLearningAppDatePicker's DatePickerDialog, then
// unmounts SelfPacedGoalStep (via a ValueListenableBuilder toggle) while the
// dialog is still open — mirroring the wizard popping this step mid-pick —
// and finally taps the dialog's OK button so the awaited Future resolves
// with a non-null DateTime, exercising exactly the vulnerable
// `if (picked != null) { setState(...) }` continuation.
@Tags(['tracks'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart'
    show ActiveProfileId, activeProfileIdProvider;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

// Deliberately Gregorian (not Hebrew) so _pickDeadline takes the
// showLearningAppDatePicker branch, which pushes a real, drivable
// DatePickerDialog on the app Navigator.
class _FalseUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  String? build() => '01J6Q2H4A8M7K3P9R5T6V8WXYC';
}

class _AshkenaziVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

// ── Setup ─────────────────────────────────────────────────────────────────────

List<Override> _overrides() {
  final contentRepo = _MockContentRepository();

  when(
    () => contentRepo.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);

  return [
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
    scopedCurriculumContentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => const <ContentItem>[]),
    scopedItemCountProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => 0),
    currentTransliterationVariantProvider.overrideWith(
      () => _AshkenaziVariant(),
    ),
  ];
}

/// Hosts [SelfPacedGoalStep] behind a [ValueNotifier]<bool> so the test can
/// unmount just the step widget (not the whole ProviderScope/Navigator) mid
/// date-pick, mirroring the Add-Track wizard popping this step while the
/// date picker dialog is still open.
Widget _toggleableHost(ValueNotifier<bool> show, List<Override> overrides) {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;

  return ProviderScope(
    retry: (_, __) => null,
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, visible, _) => visible
              ? SelfPacedGoalStep(
                  curriculumId: CurriculumId.mishnayos,
                  studyDays: const {
                    1: 'study',
                    2: 'study',
                    3: 'study',
                    4: 'study',
                    5: 'study',
                  },
                  onComplete: (_) {},
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  testWidgets(
    '_pickDeadline does not throw when the step is unmounted while the '
    'date picker Future is pending (AUD-tracks-09)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final show = ValueNotifier<bool>(true);
      addTearDown(show.dispose);

      await tester.pumpWidget(_toggleableHost(show, _overrides()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Deadline card starts inactive (default mode is 'pace') — tapping its
      // BlurInactiveGoalOption overlay triggers _activateDeadlineMode(),
      // which awaits _pickDeadline() and opens the real date picker dialog.
      final deadlineOverlay = find.byType(BlurInactiveGoalOption);
      expect(
        deadlineOverlay,
        findsOneWidget,
        reason:
            'The deadline card must be showing its inactive (blurred) '
            'overlay before the tap can be driven.',
      );

      await tester.tap(deadlineOverlay);
      // Runs _activateDeadlineMode()'s synchronous setState, then
      // _pickDeadline() up to its await on showLearningAppDatePicker(...).
      await tester.pump();
      // Let the dialog route's push transition build.
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(DatePickerDialog),
        findsOneWidget,
        reason:
            'Tapping the inactive deadline card must open the date picker '
            'dialog — the async gap this finding guards.',
      );

      // Unmount the step (disposing its State) while the date picker's
      // Future is still pending — the dialog itself lives on the app-level
      // Navigator, so it survives the step's removal.
      show.value = false;
      await tester.pump();

      // Resolve the pending Future with a non-null DateTime by tapping OK,
      // exercising the vulnerable `if (picked != null) { setState(...) }`
      // continuation after the step has already been disposed.
      final okButton = find.widgetWithText(TextButton, 'OK');
      expect(
        okButton,
        findsOneWidget,
        reason:
            'The date picker dialog must still be present and OK-able '
            'after the underlying step widget was unmounted.',
      );
      await tester.tap(okButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Resuming _pickDeadline after the step was unmounted mid-await '
            'must not throw — a mounted guard must short-circuit before '
            'calling setState.',
      );
    },
  );
}
