// Mirror test for
// `lib/features/sacred_time/presentation/widgets/learner_location_prompt.dart`
// (DNI-481 AC-2, UX-DR-99): after a fail-closed lock of a learner with no
// location, the parent is prompted to set it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/learner_location_prompt.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

/// Monday 2026-09-07 12:00Z: the no-location New York Shabbos lock ended
/// Sunday 01:00 EDT (05:00Z).
final _monday = DateTime.utc(2026, 9, 7, 12);
final _lockEnd = DateTime.utc(2026, 9, 6, 5);

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: '01ARZ3NDEKTSV4RRFFQ69G5FB3',
    ownerUid: 'parent-uid',
    grantId: 'grant-1',
    permissions: TutorPermissions(),
  );
}

List<Override> _overrides({
  LearnerSettingsHistory? history,
  SacredWindow? window,
  bool tutored = false,
}) => [
  useHebrewTermsProvider.overrideWithValue(false),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  localDayClockProvider.overrideWithValue(FakeLocalDayClock(_monday)),
  currentSacredWindowProvider.overrideWithValue(window),
  activeLearnerScopeProvider.overrideWith((ref) async => _scope),
  learnerLockSettingsProvider(
    _scope,
  ).overrideWithValue(AsyncData(history ?? constantHistory(newYorkNoLocation))),
  if (tutored) activeTutoredProfileSelectionProvider.overrideWith(_Tutored.new),
];

Future<LearnerLocationPrompt?> _read(List<Override> overrides) async {
  final container = ProviderContainer.test(overrides: overrides);
  await container.read(activeLearnerScopeProvider.future);
  return container.read(learnerLocationPromptProvider);
}

void main() {
  group('learnerLocationPromptProvider', () {
    test(
      'a learner with no location whose lock has ended is prompted',
      () async {
        expect(
          await _read(_overrides()),
          LearnerLocationPrompt(profileId: profileUlid, lockEndUtc: _lockEnd),
        );
      },
    );

    test('no prompt for a learner with a location', () async {
      expect(
        await _read(_overrides(history: constantHistory(lakewood))),
        isNull,
      );
    });

    test('no prompt during a lock, or in a tutored session', () async {
      expect(
        await _read(
          _overrides(
            window: SacredWindow(
              startUtc: _monday,
              endUtc: _monday,
              kind: SacredWindowKind.yomTov,
            ),
          ),
        ),
        isNull,
      );
      expect(await _read(_overrides(tutored: true)), isNull);
    });
  });

  group('LearnerLocationPromptListener', () {
    testWidgets('shows the prompt once; its action opens the location '
        'picker', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: MaterialApp(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => LearnerLocationPromptListener(
              onSetLocation: () async => opened++,
              child: child!,
            ),
            home: const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('This learner has no location'),
        findsOneWidget,
      );
      await tester.tap(find.text('Set location'));
      await tester.pump();
      expect(opened, 1);
    });
  });
}
