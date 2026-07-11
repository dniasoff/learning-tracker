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
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void _noopCreated({
  required ProfileModel profile,
  required bool isChildMode,
  required bool useHebrewCalendar,
  required bool useHebrewTerms,
  required bool showNikud,
  required dynamic transliterationVariant,
}) {}

void main() {
  setUpAll(() {
    registerFallbackValue('adult');
  });

  testWidgets(
    '_createProfile does not throw when the step is unmounted mid-await '
    '(AUD-onboarding-01)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final repo = _MockProfileRepository();
      when(
        () => repo.getProfilesByAccount(any()),
      ).thenAnswer((_) async => <ProfileModel>[]);
      final createGate = Completer<ProfileModel>();
      final createdProfile = ProfileModel(
        id: 7,
        accountId: 1,
        displayName: 'Yael',
        mode: 'adult',
        avatarIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      addTearDown(() {
        if (!createGate.isCompleted) createGate.complete(createdProfile);
      });

      when(
        () => repo.createProfile(
          accountId: any(named: 'accountId'),
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
          avatarIndex: any(named: 'avatarIndex'),
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
            currentAccountIdProvider.overrideWithValue(1),
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
