// AUD-onboarding-01 (SM-4) regression guard for
// OnboardingProfileCreationStep._createProfile.
//
// _createProfile awaits repo.createProfile(...) and then, on success,
// immediately touches `ref` (ref.read(selectedProfileIdProvider.notifier))
// with no `mounted` guard in between. If the step widget is unmounted while
// that create-profile call is still in flight (e.g. the user backs out of
// onboarding), resuming and touching `ref` on the disposed State throws.
@Tags(['onboarding'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void _noopCreated({
  required LearnerProfileEntity profile,
  required bool isChildMode,
  required bool useHebrewCalendar,
  required bool useHebrewTerms,
  required bool showNikud,
  required dynamic transliterationVariant,
}) {}

void main() {
  setUpAll(() {
    registerFallbackValue(ProfileMode.adult);
  });

  testWidgets(
    '_createProfile does not throw when the step is unmounted mid-await '
    '(AUD-onboarding-01)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final repo = _MockProfileRepository();
      when(
        () => repo.getProfiles(),
      ).thenAnswer((_) async => <LearnerProfileEntity>[]);
      final createGate = Completer<LearnerProfileEntity>();
      final createdProfile = LearnerProfileEntity(
        profileId: 'ulid-7',
        displayName: 'Yael',
        mode: ProfileMode.adult,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      addTearDown(() {
        if (!createGate.isCompleted) createGate.complete(createdProfile);
      });

      when(
        () => repo.createProfile(
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer((_) => createGate.future);

      // A boolean flag lets the test unmount just the step widget (not the
      // whole ProviderScope) — mirroring the wizard popping this step while
      // profile creation is in flight.
      final showStep = ValueNotifier<bool>(true);
      addTearDown(showStep.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: showStep,
                builder: (context, show, _) => show
                    ? const OnboardingProfileCreationStep(
                        onCreated: _noopCreated,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField).first, 'Yael');
      await tester.pump();

      final createButtonFinder = find.widgetWithText(
        FilledButton,
        'Create Profile',
      );
      await tester.ensureVisible(createButtonFinder);
      await tester.pump();
      await tester.tap(createButtonFinder);
      // Let _createProfile run up to the gated repo.createProfile await.
      await tester.pump();

      // Unmount the step while createProfile() is still pending.
      showStep.value = false;
      await tester.pump();

      // Resolve createProfile() now that the widget is gone.
      createGate.complete(createdProfile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Resuming after the widget was unmounted mid-await must not '
            'throw — a mounted guard must short-circuit before touching ref.',
      );
    },
  );
}
