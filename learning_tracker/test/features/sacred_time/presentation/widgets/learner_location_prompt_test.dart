// Mirror test for
// `lib/features/sacred_time/presentation/widgets/learner_location_prompt.dart`
// (DNI-481 AC-2, UX-DR-99): after a fail-closed lock of a learner with no
// location, the parent is prompted to set it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/lock_cover_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/learner_location_prompt.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _sibling = '01ARZ3NDEKTSV4RRFFQ69G5FB2';
final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);
final _siblingScope = LearnerScope(ownerUid: 'owner-uid', profileId: _sibling);

LearnerProfileEntity _profile(String id, String name) => LearnerProfileEntity(
  profileId: id,
  displayName: name,
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

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

/// The active learner is [profileUlid] ("Avi"); the account also holds
/// [_sibling] ("Bina"). Each learner's history defaults to no location.
List<Override> _overrides({
  LearnerSettingsHistory? history,
  LearnerSettingsHistory? siblingHistory,
  bool withSibling = false,
  SacredWindow? window,
  bool tutored = false,
}) => [
  useHebrewTermsProvider.overrideWithValue(false),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  localDayClockProvider.overrideWithValue(FakeLocalDayClock(_monday)),
  currentSacredWindowProvider.overrideWithValue(window),
  lockDrivingScopesProvider.overrideWithValue(
    AsyncData([_scope, if (withSibling) _siblingScope]),
  ),
  profileListStreamProvider.overrideWith(
    (ref) => Stream.value([
      _profile(profileUlid, 'Avi'),
      if (withSibling) _profile(_sibling, 'Bina'),
    ]),
  ),
  learnerLockSettingsProvider(
    _scope,
  ).overrideWithValue(AsyncData(history ?? constantHistory(newYorkNoLocation))),
  learnerLockSettingsProvider(_siblingScope).overrideWithValue(
    AsyncData(siblingHistory ?? constantHistory(newYorkNoLocation)),
  ),
  if (tutored) activeTutoredProfileSelectionProvider.overrideWith(_Tutored.new),
];

Future<List<LearnerLocationPrompt>> _read(List<Override> overrides) async {
  final container = ProviderContainer.test(overrides: overrides);
  addTearDown(container.dispose);
  final sub = container.listen(learnerLocationPromptsProvider, (_, _) {});
  addTearDown(sub.close);
  final profiles = container.listen(profileListStreamProvider, (_, _) {});
  addTearDown(profiles.close);
  await container.read(profileListStreamProvider.future);
  return container.read(learnerLocationPromptsProvider);
}

void main() {
  group('learnerLocationPromptsProvider', () {
    test(
      'a learner with no location whose lock has ended is prompted',
      () async {
        final prompts = await _read(_overrides());
        expect(prompts, [
          LearnerLocationPrompt(profileId: profileUlid, lockEndUtc: _lockEnd),
        ]);
        expect(prompts.single.displayName, 'Avi');
      },
    );

    test('no prompt for a learner with a location', () async {
      expect(
        await _read(_overrides(history: constantHistory(lakewood))),
        isEmpty,
      );
    });

    test('multi-learner: a sibling with no location that drove the lock is '
        'prompted for by its own identity, not the active learner', () async {
      final prompts = await _read(
        _overrides(withSibling: true, history: constantHistory(lakewood)),
      );
      expect(prompts, [
        LearnerLocationPrompt(profileId: _sibling, lockEndUtc: _lockEnd),
      ]);
      expect(prompts.single.displayName, 'Bina');
    });

    test(
      'multi-learner: every own learner with no location is prompted',
      () async {
        final prompts = await _read(_overrides(withSibling: true));
        expect(prompts.map((p) => p.profileId), [profileUlid, _sibling]);
      },
    );

    test('no prompt during a lock, or in a tutored session', () async {
      expect(
        await _read(
          _overrides(
            withSibling: true,
            window: SacredWindow(
              startUtc: _monday,
              endUtc: _monday,
              kind: SacredWindowKind.yomTov,
            ),
          ),
        ),
        isEmpty,
      );
      expect(await _read(_overrides(tutored: true)), isEmpty);
    });

    test('no prompt while a lock cover is still up (releasing)', () async {
      final container = ProviderContainer.test(overrides: _overrides());
      final sub = container.listen(learnerLocationPromptsProvider, (_, _) {});
      addTearDown(sub.close);
      final profiles = container.listen(profileListStreamProvider, (_, _) {});
      addTearDown(profiles.close);
      await container.read(profileListStreamProvider.future);
      final cover = Object();
      container.read(lockCoversProvider.notifier).engage(cover);
      expect(container.read(learnerLocationPromptsProvider), isEmpty);
      container.read(lockCoversProvider.notifier).release(cover);
      expect(container.read(learnerLocationPromptsProvider), hasLength(1));
    });
  });

  group('LearnerLocationPromptListener', () {
    Future<List<LearnerLocationPrompt>> pumpListener(
      WidgetTester tester,
      List<Override> overrides,
    ) async {
      final opened = <LearnerLocationPrompt>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => LearnerLocationPromptListener(
              onSetLocation: (prompt) async => opened.add(prompt),
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
      return opened;
    }

    testWidgets('shows the prompt once, naming the learner; its action opens '
        'the location picker for that learner', (tester) async {
      final opened = await pumpListener(tester, _overrides());

      expect(find.textContaining('Avi has no location'), findsOneWidget);
      await tester.tap(find.text('Set location'));
      await tester.pump();
      expect(opened, [
        LearnerLocationPrompt(profileId: profileUlid, lockEndUtc: _lockEnd),
      ]);
    });

    testWidgets("multi-learner: the sibling's prompt carries the sibling's "
        'identity to the location picker', (tester) async {
      final opened = await pumpListener(
        tester,
        _overrides(withSibling: true, history: constantHistory(lakewood)),
      );

      expect(find.textContaining('Bina has no location'), findsOneWidget);
      await tester.tap(find.text('Set location'));
      await tester.pump();
      expect(opened.single.profileId, _sibling);
    });

    testWidgets('with the lock overlay: the prompt shows after the lock '
        'lifts, after the cover discarded what was requested during it, '
        'and is not swept by that discard', (tester) async {
      final lockedWindow = SacredWindow(
        startUtc: _monday.subtract(const Duration(hours: 1)),
        endUtc: _monday.add(const Duration(hours: 1)),
        kind: SacredWindowKind.shabbos,
      );
      final container = ProviderContainer(
        overrides: _overrides(window: lockedWindow),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => LearnerLocationPromptListener(
              onSetLocation: (_) async {},
              child: SacredTimeLockOverlay(child: child!),
            ),
            home: const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('has no location'), findsNothing);
      rootScaffoldMessengerKey.currentState!.showSnackBar(
        const SnackBar(content: Text('DURING LOCK')),
      );
      await tester.pumpAndSettle();

      container.updateOverrides(_overrides());
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('DURING LOCK'), findsNothing);
      expect(find.textContaining('Avi has no location'), findsOneWidget);
    });
  });

  group('runLearnerLocationPromptAction (multi-learner PIN boundary)', () {
    final siblingPrompt = LearnerLocationPrompt(
      profileId: _sibling,
      lockEndUtc: _lockEnd,
    );

    Future<List<String>> run({
      required LearnerLocationPrompt prompt,
      required bool authorized,
      String selected = profileUlid,
      bool switchLands = true,
    }) async {
      final calls = <String>[];
      var current = selected;
      await runLearnerLocationPromptAction(
        prompt,
        selectedProfileId: () => current,
        authorize: (target) async {
          calls.add('authorize:$target');
          return authorized;
        },
        switchTo: (id) async {
          calls.add('switch:$id');
          if (switchLands) current = id;
          return true;
        },
        openCityPicker: () async => calls.add('picker:$current'),
      );
      return calls;
    }

    test('a sibling prompt authorizes the SIBLING, then switches to it and '
        'opens its picker', () async {
      expect(await run(prompt: siblingPrompt, authorized: true), [
        'authorize:$_sibling',
        'switch:$_sibling',
        'picker:$_sibling',
      ]);
    });

    test('refused for the target: no switch and no picker, so no governed '
        'write can follow', () async {
      expect(await run(prompt: siblingPrompt, authorized: false), [
        'authorize:$_sibling',
      ]);
    });

    test('a switch that did not land on the target opens no picker', () async {
      expect(
        await run(prompt: siblingPrompt, authorized: true, switchLands: false),
        ['authorize:$_sibling', 'switch:$_sibling'],
      );
    });

    test('the active learner: authorized, no switch, picker', () async {
      expect(
        await run(
          prompt: LearnerLocationPrompt(
            profileId: profileUlid,
            lockEndUtc: _lockEnd,
          ),
          authorized: true,
        ),
        ['authorize:$profileUlid', 'picker:$profileUlid'],
      );
    });
  });
}
